import { useState } from 'react';
import { gql } from '../lib/api';
import { Q, save } from '../lib/queries';
import { ErrorBox, Modal, useAction, useLoad } from '../components/ui';
import { PROOF_LABEL } from '../lib/format';

const P = save('ProofProfile', 'id name pickup { scan photo signature geoloc otp } delivery { scan photo signature geoloc otp }');
const TYPES = Object.keys(PROOF_LABEL);
const empty = () => Object.fromEntries(TYPES.map((t) => [t, false]));

// Profils de preuve (spec §5.2) : exigences séparées pour la collecte et la livraison
export default function ProofProfiles() {
  const { data, error, reload } = useLoad(async () => (await gql(Q.listProofProfiles)).listProofProfiles.items);
  const [edit, setEdit] = useState(null);
  const a = useAction();
  if (error) return <ErrorBox error={error} />;
  const clean = (r) => Object.fromEntries(TYPES.map((t) => [t, Boolean(r?.[t])]));
  const submit = () => a.run(async () => {
    await gql(edit.isNew ? P.create : P.update, { input: { id: edit.id, name: edit.name, pickup: clean(edit.pickup), delivery: clean(edit.delivery) } });
    setEdit(null); reload();
  });
  const summary = (r) => TYPES.filter((t) => r?.[t]).map((t) => PROOF_LABEL[t]).join(', ') || 'Aucune';
  return (
    <>
      <div className="head"><h1>Profils de preuve</h1><span className="spacer" />
        <button className="btn" onClick={() => setEdit({ id: '', name: '', pickup: empty(), delivery: empty(), isNew: true })}>Nouveau profil</button></div>
      <p className="muted">Le profil le plus précis l’emporte : type de client, puis client, puis demande, puis colis. À un point, la signature, la photo, la position et le code sont demandés une fois ; le scan colis par colis.</p>
      <div className="card table-wrap">
        <table><thead><tr><th>Profil</th><th>À la collecte</th><th>À la livraison</th></tr></thead>
          <tbody>{(data || []).map((p) => (
            <tr key={p.id} className="click" onClick={() => setEdit({ ...p, pickup: clean(p.pickup), delivery: clean(p.delivery), isNew: false })}>
              <td><b>{p.name}</b> <code>{p.id}</code></td><td>{summary(p.pickup)}</td><td>{summary(p.delivery)}</td></tr>
          ))}</tbody></table>
      </div>
      {edit && (
        <Modal title={edit.isNew ? 'Nouveau profil' : edit.name} onClose={() => setEdit(null)} actions={<>
          <button className="btn ghost" onClick={() => setEdit(null)}>Annuler</button>
          <button className="btn" disabled={a.busy || !edit.id || !edit.name} onClick={submit}>Enregistrer</button></>}>
          <ErrorBox error={a.error} />
          <div className="form">
            <label className="f">Identifiant<input value={edit.id} disabled={!edit.isNew} onChange={(e) => setEdit({ ...edit, id: e.target.value })} placeholder="securise" /></label>
            <label className="f">Nom<input value={edit.name} onChange={(e) => setEdit({ ...edit, name: e.target.value })} placeholder="Sécurisé" /></label>
          </div>
          <table style={{ marginTop: 12 }}><thead><tr><th>Preuve</th><th>Collecte</th><th>Livraison</th></tr></thead>
            <tbody>{TYPES.map((t) => (
              <tr key={t}><td>{PROOF_LABEL[t]}</td>
                {['pickup', 'delivery'].map((k) => <td key={k}><input type="checkbox" aria-label={`${PROOF_LABEL[t]} ${k}`} checked={edit[k][t]} onChange={(e) => setEdit({ ...edit, [k]: { ...edit[k], [t]: e.target.checked } })} /></td>)}</tr>
            ))}</tbody></table>
        </Modal>
      )}
    </>
  );
}
