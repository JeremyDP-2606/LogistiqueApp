import { useState } from 'react';
import { gql, parseJson } from '../lib/amplify';
import { Q, save } from '../lib/queries';
import { ErrorBox, Modal, useAction, useLoad } from '../components/ui';

const CUSTOMER_FIELDS = 'id name customerTypeId billingMode labelMode dedicated proofProfileId defaults labelEmail { enabled emails leadHours } tracking { route showEta showStopsBefore showLivePosition }';
const C = save('Customer', CUSTOMER_FIELDS);
const T = save('CustomerType', 'id name proofProfileId');

const blank = { id: '', name: '', customerTypeId: '', billingMode: 'ACCOUNT', labelMode: 'FLEXIBLE', dedicated: false, proofProfileId: '',
  defaults: { parcelCount: 1, size: 'S', pickupAddress: '', pickupName: '' },
  labelEmail: { enabled: false, emails: [], leadHours: 24 }, tracking: { route: 'NONE', showEta: false, showStopsBefore: false, showLivePosition: true } };

// Clients et types de clients (spec §10, §11 ter)
export default function Customers() {
  const { data, error, reload } = useLoad(async () => ({
    customers: (await gql(Q.listCustomers)).listCustomers.items.sort((a, b) => a.name.localeCompare(b.name)),
    types: (await gql(Q.listCustomerTypes)).listCustomerTypes.items,
    profiles: (await gql(Q.listProofProfiles)).listProofProfiles.items,
  }));
  const [edit, setEdit] = useState(null);
  const [isNew, setIsNew] = useState(false);
  const [typeEdit, setTypeEdit] = useState(null);
  const a = useAction();
  if (error) return <ErrorBox error={error} />;
  if (!data) return <div className="empty">Chargement…</div>;
  const typeName = (id) => data.types.find((t) => t.id === id)?.name || '—';
  const profileName = (id) => data.profiles.find((p) => p.id === id)?.name || 'Hérité du type';

  const open = (c) => {
    setIsNew(!c);
    const v = c ? { ...blank, ...c, defaults: { ...blank.defaults, ...(parseJson(c.defaults) || {}) }, labelEmail: { ...blank.labelEmail, ...(c.labelEmail || {}) }, tracking: { ...blank.tracking, ...(c.tracking || {}) } } : blank;
    setEdit({ ...v, emailsText: (v.labelEmail.emails || []).join(', ') });
  };
  const submit = () => a.run(async () => {
    const { emailsText, ...c } = edit;
    const input = {
      id: c.id.trim(), name: c.name.trim(), customerTypeId: c.customerTypeId || null, billingMode: c.billingMode, labelMode: c.labelMode,
      dedicated: Boolean(c.dedicated), proofProfileId: c.proofProfileId || null, defaults: JSON.stringify(c.defaults),
      labelEmail: { ...c.labelEmail, leadHours: Number(c.labelEmail.leadHours), emails: emailsText.split(/[,;\s]+/).filter(Boolean) },
      tracking: c.tracking,
    };
    await gql(isNew ? C.create : C.update, { input });
    setEdit(null); reload();
  });
  const saveType = () => a.run(async () => {
    await gql(typeEdit.isNew ? T.create : T.update, { input: { id: typeEdit.id, name: typeEdit.name, proofProfileId: typeEdit.proofProfileId || null } });
    setTypeEdit(null); reload();
  });
  const set = (path, value) => {
    const [k, sub] = path.split('.');
    setEdit(sub ? { ...edit, [k]: { ...edit[k], [sub]: value } } : { ...edit, [k]: value });
  };

  return (
    <>
      <div className="head"><h1>Clients</h1><span className="spacer" /><button className="btn" onClick={() => open(null)}>Nouveau client</button></div>
      <div className="card table-wrap">
        <table><thead><tr><th>Client</th><th>Type</th><th>Facturation</th><th>Étiquettes</th><th>Tournées</th><th>Preuves</th></tr></thead>
          <tbody>{data.customers.map((c) => (
            <tr key={c.id} className="click" onClick={() => open(c)}>
              <td><b>{c.name}</b><div className="small muted"><code>{c.id}</code></div></td><td>{typeName(c.customerTypeId)}</td>
              <td>{c.billingMode === 'ACCOUNT' ? 'Compte (fin de mois)' : 'À la course'}</td>
              <td>{c.labelMode === 'STRICT' ? 'Strict' : 'Souple'}{c.labelEmail?.enabled ? ` · envoi ${c.labelEmail.leadHours} h avant` : ''}</td>
              <td>{c.dedicated ? 'Toujours dédiées' : 'Mutualisées'}</td><td>{profileName(c.proofProfileId)}</td></tr>
          ))}</tbody></table>
      </div>
      <div className="card">
        <div className="row"><h2 style={{ margin: 0 }}>Types de clients</h2><span style={{ flex: 1 }} />
          <button className="btn ghost small" onClick={() => setTypeEdit({ id: '', name: '', proofProfileId: '', isNew: true })}>Ajouter un type</button></div>
        <table><tbody>{data.types.map((t) => (
          <tr key={t.id} className="click" onClick={() => setTypeEdit({ ...t, isNew: false })}><td><b>{t.name}</b> <code>{t.id}</code></td><td>Preuves par défaut : {profileName(t.proofProfileId)}</td></tr>
        ))}</tbody></table>
      </div>
      {edit && (
        <Modal title={isNew ? 'Nouveau client' : edit.name} onClose={() => setEdit(null)} actions={<>
          <button className="btn ghost" onClick={() => setEdit(null)}>Annuler</button>
          <button className="btn" disabled={a.busy || !edit.id || !edit.name} onClick={submit}>Enregistrer</button></>}>
          <ErrorBox error={a.error} />
          <div className="form">
            <label className="f">Identifiant (custom:clientName)<input value={edit.id} disabled={!isNew} onChange={(e) => set('id', e.target.value)} /></label>
            <label className="f">Nom<input value={edit.name} onChange={(e) => set('name', e.target.value)} /></label>
            <label className="f">Type de client<select value={edit.customerTypeId || ''} onChange={(e) => set('customerTypeId', e.target.value)}><option value="">—</option>
              {data.types.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}</select></label>
            <label className="f">Facturation<select value={edit.billingMode} onChange={(e) => set('billingMode', e.target.value)}>
              <option value="ACCOUNT">Compte (fin de mois)</option><option value="PER_ORDER">À la course (Stripe)</option></select></label>
            <label className="f">Étiquettes<select value={edit.labelMode} onChange={(e) => set('labelMode', e.target.value)}>
              <option value="FLEXIBLE">Souple (réserve autorisée)</option><option value="STRICT">Strict (une étiquette = un colis)</option></select></label>
            <label className="f">Profil de preuve<select value={edit.proofProfileId || ''} onChange={(e) => set('proofProfileId', e.target.value)}>
              <option value="">Hérité du type</option>{data.profiles.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
            <label className="f">Colis par défaut<input type="number" min="1" value={edit.defaults.parcelCount} onChange={(e) => set('defaults.parcelCount', Number(e.target.value))} /></label>
            <label className="f">Taille par défaut<select value={edit.defaults.size} onChange={(e) => set('defaults.size', e.target.value)}>{['S', 'M', 'L', 'XL'].map((s) => <option key={s}>{s}</option>)}</select></label>
            <label className="f">Collecte par défaut<input value={edit.defaults.pickupAddress} onChange={(e) => set('defaults.pickupAddress', e.target.value)} /></label>
            <label className="f">Contact de collecte<input value={edit.defaults.pickupName} onChange={(e) => set('defaults.pickupName', e.target.value)} /></label>
          </div>
          <label className="row small" style={{ marginTop: 10 }}><input type="checkbox" checked={edit.dedicated} onChange={(e) => set('dedicated', e.target.checked)} /> Toujours en tournée dédiée</label>
          <h3 style={{ marginTop: 16 }}>Envoi automatique des étiquettes</h3>
          <label className="row small"><input type="checkbox" checked={edit.labelEmail.enabled} onChange={(e) => set('labelEmail.enabled', e.target.checked)} disabled={edit.billingMode === 'PER_ORDER'} /> Activé {edit.billingMode === 'PER_ORDER' && '(non proposé aux clients à la course)'}</label>
          <div className="form" style={{ marginTop: 8 }}>
            <label className="f">Destinataires<input value={edit.emailsText} onChange={(e) => setEdit({ ...edit, emailsText: e.target.value })} placeholder="logistique@client.fr, …" /></label>
            <label className="f">Délai avant la tournée (h)<select value={edit.labelEmail.leadHours} onChange={(e) => set('labelEmail.leadHours', e.target.value)}>{[48, 24, 12, 6].map((h) => <option key={h} value={h}>{h} h</option>)}</select></label>
          </div>
          <h3 style={{ marginTop: 16 }}>Suivi par le client</h3>
          <div className="form">
            <label className="f">Trajet affiché<select value={edit.tracking.route} onChange={(e) => set('tracking.route', e.target.value)}>
              <option value="NONE">Aucun (par défaut)</option><option value="OWN">Entre ses points seulement</option><option value="FULL">Itinéraire réel complet</option></select></label>
          </div>
          <div className="row small" style={{ marginTop: 8 }}>
            <label className="row"><input type="checkbox" checked={edit.tracking.showLivePosition} onChange={(e) => set('tracking.showLivePosition', e.target.checked)} /> Position du livreur</label>
            <label className="row"><input type="checkbox" checked={edit.tracking.showEta} onChange={(e) => set('tracking.showEta', e.target.checked)} /> Heure estimée</label>
            <label className="row"><input type="checkbox" checked={edit.tracking.showStopsBefore} onChange={(e) => set('tracking.showStopsBefore', e.target.checked)} /> Arrêts restants avant le sien</label>
          </div>
        </Modal>
      )}
      {typeEdit && (
        <Modal title={typeEdit.isNew ? 'Nouveau type de client' : typeEdit.name} onClose={() => setTypeEdit(null)} actions={<>
          <button className="btn ghost" onClick={() => setTypeEdit(null)}>Annuler</button>
          <button className="btn" disabled={a.busy || !typeEdit.id || !typeEdit.name} onClick={saveType}>Enregistrer</button></>}>
          <ErrorBox error={a.error} />
          <div className="form">
            <label className="f">Identifiant<input value={typeEdit.id} disabled={!typeEdit.isNew} onChange={(e) => setTypeEdit({ ...typeEdit, id: e.target.value })} placeholder="grand-compte" /></label>
            <label className="f">Nom<input value={typeEdit.name} onChange={(e) => setTypeEdit({ ...typeEdit, name: e.target.value })} /></label>
            <label className="f">Profil de preuve par défaut<select value={typeEdit.proofProfileId || ''} onChange={(e) => setTypeEdit({ ...typeEdit, proofProfileId: e.target.value })}>
              <option value="">Aucun</option>{data.profiles.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
          </div>
        </Modal>
      )}
    </>
  );
}
