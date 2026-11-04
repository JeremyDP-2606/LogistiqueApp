import { useState } from 'react';
import { Link } from 'react-router-dom';
import Papa from 'papaparse';
import { gql, parseJson } from '../lib/api';
import { M, Q } from '../lib/queries';
import { ErrorBox, useAction, useLoad } from '../components/ui';

// Champs internes qu'une source peut fournir (spec §4.1)
const FIELDS = [
  ['externalRef', 'Référence client'], ['deliveryName', 'Destinataire'], ['deliveryPhone', 'Téléphone'], ['deliveryEmail', 'E-mail'],
  ['deliveryAddress', 'Adresse de livraison'], ['instructions', 'Instructions'], ['parcelCount', 'Nombre de colis'], ['size', 'Taille'],
  ['weightKg', 'Poids (kg)'], ['deadlineAt', 'Heure limite'], ['pickupAddress', 'Adresse de collecte'],
];

// Import de fichiers CSV / Excel exporté en CSV (spec §4)
export default function Import() {
  const { data: ref } = useLoad(async () => ({
    customers: (await gql(Q.listCustomers)).listCustomers.items,
    connectors: (await gql(Q.listConnectors)).listConnectors.items,
  }));
  const [customerId, setCustomerId] = useState('');
  const [connectorId, setConnectorId] = useState('');
  const [rows, setRows] = useState([]);
  const [columns, setColumns] = useState([]);
  const [manual, setManual] = useState({});
  const [result, setResult] = useState(null);
  const a = useAction();
  const connectors = (ref?.connectors || []).filter((c) => c.customerId === customerId);

  const onFile = (file) => {
    setResult(null);
    Papa.parse(file, {
      header: true, skipEmptyLines: true, delimitersToGuess: [';', ',', '\t'],
      complete: (r) => {
        setRows(r.data);
        setColumns(r.meta.fields || []);
        // Correspondance automatique des colonnes portant le nom d'un champ interne
        const auto = {};
        for (const [k, label] of FIELDS) {
          const col = (r.meta.fields || []).find((c) => [k.toLowerCase(), label.toLowerCase()].includes(c.trim().toLowerCase()));
          if (col) auto[k] = col;
        }
        setManual(auto);
      },
      error: (e) => a.setError(e),
    });
  };

  const send = () => a.run(async () => {
    // Sans connecteur, la correspondance choisie ici est appliquée avant l'envoi
    const records = connectorId ? rows : rows.map((r) => Object.fromEntries(Object.entries(manual).filter(([, c]) => c).map(([k, c]) => [k, r[c]])));
    const out = [];
    for (let i = 0; i < records.length; i += 50) {
      const chunk = records.slice(i, i + 50);
      out.push(parseJson((await gql(M.ingestOrders, { customerId, source: 'IMPORT', connectorId: connectorId || undefined, records: JSON.stringify(chunk) })).ingestOrders));
    }
    setResult({ total: out.reduce((s, x) => s + x.total, 0), ready: out.reduce((s, x) => s + x.ready, 0), toFix: out.flatMap((x) => x.toFix) });
  });

  return (
    <>
      <div className="head"><h1>Import de demandes</h1></div>
      <ErrorBox error={a.error} />
      <div className="card">
        <div className="form">
          <label className="f">Client<select value={customerId} onChange={(e) => { setCustomerId(e.target.value); setConnectorId(''); }}>
            <option value="">Choisir…</option>{(ref?.customers || []).map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
          <label className="f">Connecteur (correspondance des colonnes)<select value={connectorId} onChange={(e) => setConnectorId(e.target.value)} disabled={!customerId}>
            <option value="">Correspondance manuelle ci-dessous</option>{connectors.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></label>
          <label className="f">Fichier CSV<input type="file" accept=".csv,text/csv" onChange={(e) => e.target.files[0] && onFile(e.target.files[0])} /></label>
        </div>
      </div>
      {rows.length > 0 && !connectorId && (
        <div className="card">
          <h2>Correspondance des colonnes</h2>
          <div className="form">{FIELDS.map(([k, label]) => (
            <label key={k} className="f">{label}<select value={manual[k] || ''} onChange={(e) => setManual({ ...manual, [k]: e.target.value })}>
              <option value="">—</option>{columns.map((c) => <option key={c} value={c}>{c}</option>)}</select></label>
          ))}</div>
          <p className="small muted">Sans adresse de collecte, celle par défaut du client est utilisée.</p>
        </div>
      )}
      {rows.length > 0 && (
        <div className="card table-wrap">
          <div className="row" style={{ marginBottom: 10 }}><h2 style={{ margin: 0 }}>Aperçu : {rows.length} ligne(s)</h2><span className="spacer" style={{ flex: 1 }} />
            <button className="btn" disabled={!customerId || a.busy} onClick={send}>{a.busy ? 'Import…' : `Importer ${rows.length} demande(s)`}</button></div>
          <table><thead><tr>{columns.map((c) => <th key={c}>{c}</th>)}</tr></thead>
            <tbody>{rows.slice(0, 8).map((r, i) => <tr key={i}>{columns.map((c) => <td key={c} className="small">{r[c]}</td>)}</tr>)}</tbody></table>
        </div>
      )}
      {result && (
        <div className="card">
          <h2>Résultat</h2>
          <p><b>{result.ready}</b> demande(s) prête(s) à planifier sur {result.total}. <b>{result.toFix.length}</b> à corriger.</p>
          <ul className="timeline">{result.toFix.map((o) => <li key={o.id}><Link to={`/demandes/${o.id}`}>{o.ref}</Link> : {o.anomalies.map((x) => x.message).join(' ; ')}</li>)}</ul>
        </div>
      )}
    </>
  );
}
