import { useState } from 'react';
import { gql, parseJson } from '../lib/api';
import { Q, save } from '../lib/queries';
import { ErrorBox, Modal, useAction, useLoad } from '../components/ui';
import { today } from '../lib/format';

const S = save('CommentPreset', 'id label kind clientVisible mandatory active');
const KIND = { PICKUP: 'Collecte', DELIVERY: 'Livraison', FAILURE: 'Échec' };

// Commentaires prédéfinis des livreurs et statistiques (spec §5.4)
export default function CommentPresets() {
  const monthStart = `${today().slice(0, 8)}01`;
  const { data, error, reload } = useLoad(async () => ({
    presets: (await gql(Q.listCommentPresets)).listCommentPresets.items.sort((a, b) => a.kind.localeCompare(b.kind) || a.label.localeCompare(b.label)),
    stats: parseJson((await gql(Q.commentStats, { from: monthStart, to: today() })).commentStats),
  }));
  const [edit, setEdit] = useState(null);
  const a = useAction();
  if (error) return <ErrorBox error={error} />;
  if (!data) return <div className="empty">Chargement…</div>;
  const submit = () => a.run(async () => {
    const { isNew, ...p } = edit;
    await gql(isNew ? S.create : S.update, { input: { ...(isNew ? {} : { id: p.id }), label: p.label, kind: p.kind, clientVisible: p.clientVisible, mandatory: p.mandatory, active: p.active } });
    setEdit(null); reload();
  });
  return (
    <>
      <div className="head"><h1>Commentaires prédéfinis</h1><span className="spacer" />
        <button className="btn" onClick={() => setEdit({ label: '', kind: 'DELIVERY', clientVisible: false, mandatory: false, active: 'yes', isNew: true })}>Nouveau commentaire</button></div>
      <p className="muted">Un texte libre du livreur reste toujours interne. Un commentaire prédéfini est visible par le client seulement si vous le décidez.</p>
      <div className="grid2">
        <div className="card table-wrap">
          <table><thead><tr><th>Commentaire</th><th>Usage</th><th>Visible client</th><th>Actif</th></tr></thead>
            <tbody>{data.presets.map((p) => (
              <tr key={p.id} className="click" onClick={() => setEdit({ ...p, isNew: false })}>
                <td><b>{p.label}</b>{p.mandatory && <span className="small muted"> · obligatoire</span>}</td><td>{KIND[p.kind]}</td>
                <td>{p.clientVisible ? 'Oui' : 'Non (interne)'}</td><td>{p.active === 'yes' ? 'Oui' : 'Non'}</td></tr>
            ))}</tbody></table>
        </div>
        <div className="card">
          <h2>Les plus fréquents ce mois-ci</h2>
          {data.stats.length === 0 ? <div className="empty">Pas encore de données</div> : (
            <table><thead><tr><th>Commentaire</th><th>Code postal</th><th>Nombre</th></tr></thead>
              <tbody>{data.stats.slice(0, 15).map((s, i) => <tr key={i}><td>{s.label}</td><td>{s.postalCode || '—'}</td><td>{s.count}</td></tr>)}</tbody></table>
          )}
        </div>
      </div>
      {edit && (
        <Modal title={edit.isNew ? 'Nouveau commentaire' : edit.label} onClose={() => setEdit(null)} actions={<>
          <button className="btn ghost" onClick={() => setEdit(null)}>Annuler</button>
          <button className="btn" disabled={a.busy || !edit.label} onClick={submit}>Enregistrer</button></>}>
          <ErrorBox error={a.error} />
          <div className="form">
            <label className="f">Texte<input value={edit.label} onChange={(e) => setEdit({ ...edit, label: e.target.value })} placeholder="Laissé au gardien" /></label>
            <label className="f">Usage<select value={edit.kind} onChange={(e) => setEdit({ ...edit, kind: e.target.value })}>{Object.entries(KIND).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</select></label>
          </div>
          <div className="row small" style={{ marginTop: 10 }}>
            <label className="row"><input type="checkbox" checked={edit.clientVisible} onChange={(e) => setEdit({ ...edit, clientVisible: e.target.checked })} /> Visible par le client</label>
            <label className="row"><input type="checkbox" checked={Boolean(edit.mandatory)} onChange={(e) => setEdit({ ...edit, mandatory: e.target.checked })} /> Obligatoire</label>
            <label className="row"><input type="checkbox" checked={edit.active === 'yes'} onChange={(e) => setEdit({ ...edit, active: e.target.checked ? 'yes' : 'no' })} /> Actif</label>
          </div>
        </Modal>
      )}
    </>
  );
}
