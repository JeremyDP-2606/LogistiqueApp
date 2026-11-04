// Tournage de la vidéo de démonstration : app cliente, app livreuse et back-office côte à côte,
// sur le serveur Wabap en mode démonstration (vraie logique métier, données fictives). Voir demo/README.md.
//
//   node demo/record.js            → vidéo WebM dans demo/out/
//   node demo/record.js --shots    → captures d'écran à chaque étape (mise au point)
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const MOCK = process.env.API || 'http://localhost:4000';
const CLIENT_URL = process.env.CLIENT_URL || `http://localhost:8081/?persona=client&api=${encodeURIComponent(`${MOCK}/graphql`)}`;
const COURIER_URL = process.env.COURIER_URL || `http://localhost:8082/?persona=livreur&api=${encodeURIComponent(`${MOCK}/graphql`)}`;
const BO_URL = process.env.BO_URL || 'http://localhost:5174';
const BO_CLIENT_ID = '1lq36a8msee59bdp7kek0sefsk';
const OUT = path.join(__dirname, 'out');
const SHOTS = process.argv.includes('--shots');
const DEPOT = { latitude: 14.615, longitude: -61.032 };

// Adresses proposées par la recherche d'adresse (API Google Places simulée)
const PLACES = {
  lamartine: { text: '12 Rue Lamartine, 97200 Fort-de-France, Martinique', lat: 14.6050, lng: -61.0700 },
  cluny: { text: 'Résidence Cluny, 97200 Fort-de-France, Martinique', lat: 14.6190, lng: -61.0740 },
  caraibes: { text: 'Avenue des Caraïbes, 97200 Fort-de-France, Martinique', lat: 14.6045, lng: -61.0655 },
  redoute: { text: 'Route de Redoute, 97200 Fort-de-France, Martinique', lat: 14.6340, lng: -61.0760 },
};

const CSV = [
  'Référence client;Destinataire;Téléphone;Adresse de livraison;Instructions;Nombre de colis;Taille',
  'EC-5001;MURIEL ADÉLAÏDE;0696 41 22 33;5 Rue Victor Hugo, 97200 Fort-de-France;Sonner deux fois;1;M',
  'EC-5002;THIERRY BELROSE;0696 52 33 44;18 Route de Didier, 97200 Fort-de-France;;2;L',
  'EC-5003;GISÈLE RENÉ-CORAIL;06 96 63 44 55;2 Boulevard du Général de Gaulle, 97200 Fort-de-France;Boutique au RDC;1;S',
  'EC-5004;LUDOVIC SAINTE-ROSE;0696 74 55 66;Lotissement les Hauts du Morne, 97200;;1;M',
].join('\n');

const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
const jwt = (claims) => `${b64({ alg: 'RS256', kid: 'demo' })}.${b64(claims)}.c2lnbmF0dXJl`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function gqlAs(apiKey, query, variables) {
  const r = await fetch(`${MOCK}/graphql`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-api-key': apiKey }, body: JSON.stringify({ query, variables }) });
  const j = await r.json();
  if (j.errors) throw new Error(j.errors.map((e) => e.message).join(' | '));
  return j.data;
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const ctx = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    deviceScaleFactor: 1,
    timezoneId: 'America/Martinique',
    locale: 'fr-FR',
    geolocation: DEPOT,
    permissions: ['geolocation'],
    acceptDownloads: true,
    ...(SHOTS ? {} : { recordVideo: { dir: OUT, size: { width: 1920, height: 1080 } } }),
  });

  // ---------- Réseau : AppSync simulé, Google Places simulé, pas de Cognito ----------
  const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': 'GET, POST, OPTIONS' };
  const forward = (header) => async (route) => {
    const r = route.request();
    if (r.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
    const resp = await fetch(`${MOCK}/graphql`, { method: 'POST', headers: { 'content-type': 'application/json', [header]: r.headers()[header] || '' }, body: r.postData() });
    return route.fulfill({ status: resp.status, headers: { ...cors, 'content-type': 'application/json' }, body: await resp.text() });
  };
  await ctx.route(/api\.wabap-demo\.test\/graphql/, forward('authorization'));
  await ctx.route(/cognito-identity|cognito-idp/, (route) => route.fulfill({ status: 400, contentType: 'application/json', body: '{"__type":"NotAuthorizedException","message":"démo"}' }));
  await ctx.route(/places\.googleapis\.com\/v1\//, async (route) => {
    const r = route.request();
    if (r.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
    const url = r.url();
    if (url.includes('places:autocomplete')) {
      const input = JSON.parse(r.postData() || '{}').input.toLowerCase();
      const hits = Object.entries(PLACES).filter(([, p]) => p.text.toLowerCase().includes(input.split(' ').pop()));
      const suggestions = (hits.length ? hits : Object.entries(PLACES).slice(0, 3)).map(([id, p]) => ({ placePrediction: { placeId: id, text: { text: p.text } } }));
      return route.fulfill({ status: 200, headers: { ...cors, 'content-type': 'application/json' }, body: JSON.stringify({ suggestions }) });
    }
    const id = url.match(/places\/([^?]+)/)[1];
    const p = PLACES[id];
    return route.fulfill({ status: 200, headers: { ...cors, 'content-type': 'application/json' }, body: JSON.stringify({ formattedAddress: p.text, location: { latitude: p.lat, longitude: p.lng } }) });
  });

  // Session back-office (administratrice fictive) : jetons au format Cognito, vérifiés par le seul serveur simulé
  const now = Math.floor(Date.now() / 1000);
  const base = { sub: 'admin-demo', exp: now + 7200, iat: now, iss: 'https://cognito-idp.us-east-1.amazonaws.com/us-east-1_demo', 'cognito:groups': ['admin'] };
  const idToken = jwt({ ...base, aud: BO_CLIENT_ID, token_use: 'id', email: 'nathalie@wabap.example', given_name: 'Nathalie', 'cognito:username': 'nathalie' });
  const accessToken = jwt({ ...base, client_id: BO_CLIENT_ID, token_use: 'access', username: 'nathalie' });
  await ctx.addInitScript(({ idToken, accessToken, clientId }) => {
    if (!location.port || location.port !== '5174') return;
    const k = `CognitoIdentityServiceProvider.${clientId}`;
    localStorage.setItem(`${k}.LastAuthUser`, 'nathalie');
    localStorage.setItem(`${k}.nathalie.idToken`, idToken);
    localStorage.setItem(`${k}.nathalie.accessToken`, accessToken);
    localStorage.setItem(`${k}.nathalie.refreshToken`, 'refresh');
    localStorage.setItem(`${k}.nathalie.clockDrift`, '0');
    // Met en évidence les boutons « cliqués » par la démo
    addEventListener('DOMContentLoaded', () => {
      const st = document.createElement('style');
      st.textContent = '.demo-press { outline: 4px solid #ff9500 !important; outline-offset: 2px; transform: scale(.97); transition: transform .15s; }';
      document.head.appendChild(st);
    });
  }, { idToken, accessToken, clientId: BO_CLIENT_ID });

  const page = await ctx.newPage();
  const t0 = Date.now();
  const chapters = []; // horodatage des étapes, pour la page de partage
  const errors = [];
  page.on('pageerror', (e) => errors.push(`pageerror ${e.message}`));
  if (process.env.DEBUG) {
    page.on('console', (m) => { if (m.type() === 'error') console.log(`[console] ${m.text().slice(0, 300)}`); });
    page.on('response', (r) => { if (r.status() >= 400) console.log(`[http ${r.status()}] ${r.request().method()} ${r.url().slice(0, 120)}`); });
  }
  await page.goto(`file://${path.join(__dirname, 'stage.html')}`);
  const stage = {
    caption: (step, text) => {
      if (!chapters.length || chapters[chapters.length - 1].step !== step) chapters.push({ step, text, at: Math.round((Date.now() - t0) / 100) / 10 });
      return page.evaluate(([s, t]) => window.demo.caption(s, t), [step, text]);
    },
    focus: (id) => page.evaluate((i) => window.demo.focus(i), id),
    overlay: (show, title, sub, chips, note) => page.evaluate((a) => window.demo.overlay(...a), [show, title, sub, chips, note]),
    web: (label, url) => page.evaluate(([l, u]) => window.demo.web(l, u), [label, url]),
  };
  let shot = 0;
  const snap = async (name) => { if (SHOTS) await page.screenshot({ path: path.join(OUT, `${String(++shot).padStart(2, '0')}-${name}.png`) }); };

  await stage.overlay(true, 'Wabap V2',
    'La plateforme de livraison de colis B2B et B2C : imports clients, tournées optimisées, preuves de livraison, courses à la demande et rémunération des livreurs.',
    ['App mobile cliente', 'App mobile livreur', 'Back-office exploitation', 'Back-office finance'],
    'Démonstration sur données fictives · Martinique');

  // ---------- Chargement des trois écrans ----------
  const setFrame = (name, url) => page.evaluate(([n, u]) => { document.getElementById(n).src = u; }, [name, url]);
  await setFrame('client', CLIENT_URL);
  await setFrame('courier', COURIER_URL);
  await setFrame('web', BO_URL);
  const frame = (name) => page.frame({ name });
  await sleep(SHOTS ? 9000 : 10000);

  // ---------- Outils Flutter (arbre d'accessibilité) ----------
  async function enableSemantics(name) {
    for (let i = 0; i < 20; i++) {
      const ok = await frame(name).evaluate(() => {
        const ph = document.querySelector('flt-semantics-placeholder');
        if (ph) ph.click();
        return document.querySelectorAll('flt-semantics').length > 3;
      }).catch(() => false);
      if (ok) return;
      await sleep(500);
    }
    throw new Error(`Accessibilité Flutter indisponible (${name})`);
  }
  const findIn = (name, text, opts = {}) => frame(name).evaluate(({ text, exact, nth, kind }) => {
    const sel = kind === 'field' ? 'flt-semantics input, flt-semantics textarea, input, textarea' : 'flt-semantics[flt-tappable], flt-semantics[role="button"], flt-semantics[role="checkbox"], flt-semantics[role="radio"], flt-semantics[role="tab"], flt-semantics[role="link"], flt-semantics[role="menuitem"], flt-semantics[role="switch"]';
    const label = (e) => (e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.textContent || '').replace(/\s+/g, ' ').trim();
    const els = [...document.querySelectorAll(sel)].filter((e) => {
      const l = label(e);
      if (exact ? l !== text : !l.includes(text)) return false;
      const r = e.getBoundingClientRect();
      return r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < innerHeight;
    }).sort((a, b) => label(a).length - label(b).length);
    const el = els[nth || 0];
    if (!el) return null;
    const r = el.getBoundingClientRect();
    return { x: r.x + r.width / 2, y: r.y + r.height / 2, label: label(el) };
  }, { text, ...opts });
  async function tap(name, text, opts = {}) {
    const deadline = Date.now() + (opts.timeout || 15000);
    for (;;) {
      const hit = await findIn(name, text, opts).catch(() => null);
      if (hit) {
        await frame(name).evaluate(({ text, exact, nth }) => {
          const sel = 'flt-semantics[flt-tappable], flt-semantics[role="button"], flt-semantics[role="checkbox"], flt-semantics[role="radio"], flt-semantics[role="tab"], flt-semantics[role="link"], flt-semantics[role="menuitem"], flt-semantics[role="switch"]';
          const label = (e) => (e.getAttribute('aria-label') || e.textContent || '').replace(/\s+/g, ' ').trim();
          const els = [...document.querySelectorAll(sel)].filter((e) => {
            const l = label(e); const r = e.getBoundingClientRect();
            return (exact ? l === text : l.includes(text)) && r.width > 0 && r.height > 0 && r.bottom > 0 && r.top < innerHeight;
          }).sort((a, b) => label(a).length - label(b).length);
          els[nth || 0].click();
        }, { text, ...opts });
        await sleep(opts.after ?? 900);
        return hit;
      }
      if (Date.now() > deadline) {
        if (opts.optional) return null;
        await page.screenshot({ path: path.join(OUT, `echec-${name}.png`) });
        throw new Error(`Élément introuvable dans ${name} : « ${text} »`);
      }
      await enableSemantics(name).catch(() => {});
      await sleep(400);
    }
  }
  const visible = async (name, text) => Boolean(await findIn(name, text).catch(() => null));
  const textOf = (name) => frame(name).evaluate(() => {
    const host = document.querySelector('flt-semantics-host');
    const inputs = [...document.querySelectorAll('input, textarea')].map((e) => e.getAttribute('aria-label') || '').join(' | ');
    return `${host ? host.textContent : ''} | ${inputs}`;
  });
  async function waitText(name, text, timeout = 15000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      if ((await textOf(name).catch(() => '')).includes(text)) return true;
      await enableSemantics(name).catch(() => {});
      await sleep(400);
    }
    throw new Error(`Texte absent dans ${name} : « ${text} »`);
  }
  async function type(name, label, value, { submit = false } = {}) {
    const deadline = Date.now() + 15000;
    for (;;) {
      const ok = await frame(name).evaluate((label) => {
        const fields = [...document.querySelectorAll('input, textarea')].filter((e) => (e.getAttribute('aria-label') || e.getAttribute('placeholder') || '').includes(label));
        if (fields[0]) { fields[0].focus(); return true; }
        // Champ pas encore actif : on touche le nœud qui porte le libellé
        const node = [...document.querySelectorAll('flt-semantics')].filter((e) => (e.textContent || e.getAttribute('aria-label') || '').includes(label))
          .sort((a, b) => a.textContent.length - b.textContent.length)[0];
        if (node) node.click();
        return false;
      }, label).catch(() => false);
      if (ok) break;
      if (Date.now() > deadline) throw new Error(`Champ introuvable dans ${name} : « ${label} »`);
      await sleep(500);
    }
    await sleep(250);
    await page.keyboard.type(value, { delay: 55 });
    if (submit) await page.keyboard.press('Enter');
    await sleep(400);
  }
  async function scroll(name, dy) {
    const el = await page.$(`#${name}`);
    const box = await el.boundingBox();
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    await page.mouse.wheel(0, dy);
    await sleep(700);
  }
  async function reload(name, url) {
    await setFrame(name, 'about:blank');
    await sleep(200);
    await setFrame(name, url);
    await sleep(4500);
    await enableSemantics(name);
  }

  // ---------- Outils back-office ----------
  const web = () => frame('web');
  async function go(pathname, label) {
    await stage.web(label, `backoffice.wabap${pathname === '/' ? '' : pathname}`);
    await web().evaluate((p) => { history.pushState({}, '', p); dispatchEvent(new PopStateEvent('popstate')); }, pathname);
    await sleep(1800);
  }
  const webClick = async (selector, opts = {}) => {
    const el = web().locator(selector).first();
    await el.waitFor({ timeout: 15000 });
    await el.evaluate((e) => { e.scrollIntoView({ block: 'center', behavior: 'smooth' }); });
    await sleep(500);
    await el.evaluate((e) => { e.classList.add('demo-press'); setTimeout(() => e.classList.remove('demo-press'), 400); e.click(); });
    await sleep(opts.after ?? 1200);
  };
  async function webScroll(dy) { await web().evaluate((d) => window.scrollBy({ top: d, behavior: 'smooth' }), dy); await sleep(1100); }

  await enableSemantics('client');
  await enableSemantics('courier');
  await sleep(1500);
  await snap('intro');
  await stage.overlay(false);
  await sleep(800);

  // =====================================================================
  // 1. Exploitation : tableau de bord
  await stage.focus('web');
  await stage.caption('1 · Exploitation', 'Le tableau de bord : tournées du jour, livreurs en route et alertes à traiter');
  await go('/', 'Exploitation');
  await sleep(3500);
  await snap('dashboard');

  // 2. Import d'un fichier client
  await stage.caption('2 · Import', 'Un client envoie ses commandes en CSV : colonnes reconnues automatiquement');
  await go('/import', 'Exploitation');
  await web().locator('label.f:has-text("Client") select').selectOption({ label: 'Enseigne Caraïbes' });
  await sleep(800);
  await web().locator('input[type=file]').setInputFiles({ name: 'commandes-enseigne.csv', mimeType: 'text/csv', buffer: Buffer.from(CSV, 'utf8') });
  await sleep(2200);
  await snap('import-mapping');
  await webScroll(700);
  await sleep(1500);
  await stage.caption('2 · Import', 'Adresses géocodées, téléphones normalisés, doublons détectés : chaque ligne est contrôlée');
  await webClick('button:has-text("Importer")', { after: 2500 });
  await webScroll(900);
  await sleep(2500);
  await snap('import-result');

  // 3. Correction d'une anomalie
  await stage.caption('3 · Anomalies', 'L’adresse incomplète part en file « à corriger » : on la rectifie en un clic');
  await webClick('.timeline a', { after: 2000 });
  const addr = web().locator('label.f:has-text("Adresse de livraison") input');
  await addr.fill('');
  await addr.pressSequentially('7 Quartier Bellevue, 97200 Fort-de-France', { delay: 35 });
  await sleep(600);
  await snap('fix');
  await webClick('button:has-text("Valider la correction")', { after: 2500 });
  await snap('fixed');

  // =====================================================================
  // 4. Cliente : commande d'une course à la demande
  await stage.focus('client');
  await stage.caption('4 · Course à la demande', 'Jessica, particulière, envoie un colis depuis l’app : adresses suggérées par Google');
  await tap('client', 'Envoyer un colis', { after: 1500 });
  await tap('client', 'Où récupérer le colis', { after: 1300 });
  await type('client', 'Numéro, rue, ville', '12 rue Lamartine');
  await sleep(1200);
  await tap('client', 'Rue Lamartine', { after: 1500 });
  await tap('client', 'Où le livrer', { after: 1300 });
  await type('client', 'Numéro, rue, ville', 'Résidence Cluny');
  await sleep(1200);
  await tap('client', 'Résidence Cluny', { after: 1500 });
  await type('client', 'Destinataire', 'Tonton Max');
  await type('client', 'Téléphone', '0696 22 33 44');
  await snap('course-adresses');
  await scroll('client', 380);
  await stage.caption('4 · Course à la demande', 'Taille, délai de 1 à 3 jours : le prix détaillé se calcule en direct');
  await tap('client', 'M —', { after: 1200 });
  await tap('client', '1 jour', { after: 1500 });
  await scroll('client', 600);
  await sleep(1500);
  await snap('course-prix');
  await stage.caption('4 · Course à la demande', 'Paiement par carte avant l’enlèvement (Stripe), remboursé en cas d’annulation');
  await tap('client', 'et commander', { after: 1800 });
  await snap('paiement');
  await tap('client', 'Payer', { exact: true, after: 3500 });
  await stage.caption('4 · Course à la demande', 'Suivi en temps réel, étiquette à imprimer et code de confirmation pour le destinataire');
  await sleep(2500);
  await snap('suivi');
  await scroll('client', 400);
  await sleep(1500);
  await scroll('client', -800);

  // =====================================================================
  // 5. Exploitation : insertion dans la tournée de Léa
  await stage.focus('web');
  await stage.caption('5 · Planification', 'La course payée est prête : on l’insère dans la tournée mutualisée de l’après-midi');
  await go('/tournees', 'Exploitation');
  await sleep(1200);
  await snap('tournees');
  await webClick('tr.click:has-text("après-midi")', { after: 2500 });
  const tourPath = await web().evaluate(() => location.pathname);
  await stage.web('Exploitation', `backoffice.wabap${tourPath.slice(0, 22)}…`);
  await webScroll(1400);
  await sleep(1000);
  const rows = web().locator('tr:has(input[type=checkbox])', { hasText: 'Jessica' });
  for (let i = 0; i < await rows.count(); i++) { await rows.nth(i).locator('input[type=checkbox]').evaluate((e) => e.click()); await sleep(500); }
  await snap('insertion');
  await stage.caption('5 · Planification', 'Ordre recalculé : collectes avant livraisons, heures limites respectées');
  await webClick('button:has-text("Insérer")', { after: 2500 });
  await web().evaluate(() => window.scrollTo({ top: 0, behavior: 'smooth' }));
  await sleep(1200);
  await webClick('button:has-text("Recalculer")', { after: 2500 });
  await webScroll(450);
  await sleep(2500);
  await snap('tournee-planifiee');

  // =====================================================================
  // 6. Livreuse : tournée de bout en bout
  await stage.focus('courier');
  await stage.caption('6 · Livreuse', 'Léa reçoit sa tournée : elle l’accepte puis la démarre (position partagée)');
  await reload('courier', COURIER_URL);
  await tap('courier', 'après-midi', { after: 2500 });
  await snap('tournee-livreuse');
  await tap('courier', 'Accepter', { exact: true, after: 2000 });
  await tap('courier', 'Démarrer la tournée', { after: 2500 });

  const tours = (await gqlAs('demo-livreur', 'query($c: ID!) { toursByCourierIdAndStartTime(courierId: $c, limit: 60) { items { id name } } }', { c: 'livreur-lea' })).toursByCourierIdAndStartTime.items;
  const leaTour = tours.find((t) => (t.name || '').includes('après-midi'));
  const view = async () => JSON.parse((await gqlAs('demo-livreur', 'query($t: ID!) { courierTourView(tourId: $t) }', { t: leaTour.id })).courierTourView);

  let failed = false;
  let clientShown = false;
  // Le back-office se met à jour pendant que la livreuse avance
  const refreshBo = async () => { await web().evaluate(() => location.reload()); await sleep(1500); await webScroll(330); };
  for (let guard = 0; guard < 12; guard++) {
    const v = await view();
    const next = v.stops.filter((s) => s.status === 'TODO').sort((a, b) => a.sequence - b.sequence)[0];
    if (!next) break;
    const place = { ...(next.address || {}), name: next.contact?.name };
    if (place.latitude) await ctx.setGeolocation({ latitude: place.latitude + 0.00012, longitude: place.longitude - 0.0001, accuracy: 8 });
    const isPickup = next.type === 'PICKUP';
    const isCourse = String(next.customerId).startsWith('IND-');
    if (isPickup) await stage.caption('6 · Collecte', `Collecte ${place.name ? `chez ${place.name}` : `au ${place.formatted.split(',')[0]}`} : chaque colis est scanné (étiquette QR signée)`);
    else await stage.caption('6 · Livraison', `Livraison ${place.name ? `à ${place.name}` : `au ${place.formatted.split(',')[0]}`} : les preuves exigées dépendent du client`);
    await tap('courier', isPickup ? 'Je suis à la collecte' : 'Je suis à la livraison', { after: 2000 });
    await snap(`point-${next.sequence}`);
    const req = next.requirements || { perStop: {}, scanParcelIds: [] };
    const toScan = req.scanParcelIds.length;
    const shouldFail = !isPickup && !failed && !isCourse && next.customerId === 'ENSEIGNE' && guard > 2;
    if (shouldFail) {
      failed = true;
      await stage.caption('6 · Échec de livraison', 'Destinataire absent : motif normé et photo obligatoires, le client est prévenu');
      await scroll('courier', 600);
      await tap('courier', 'Livraison impossible', { after: 1500 });
      await tap('courier', 'Destinataire absent', { after: 900 });
      await tap('courier', 'Photo obligatoire', { after: 1800 });
      await snap('echec');
      await tap('courier', 'Confirmer l’échec', { after: 2500 });
      await refreshBo();
      continue;
    }
    for (let i = 0; i < toScan; i++) await tap('courier', 'Scanner un colis', { after: 1700 });
    if (req.perStop.photo) await tap('courier', 'Colis ou lieu de dépôt', { after: 1700 });
    if (req.perStop.otp) {
      await stage.caption('6 · Livraison', 'Course ponctuelle : photo + code à 4 chiffres communiqué par l’expéditrice');
      const orderId = next.orderIds[0];
      const t = JSON.parse((await gqlAs('demo-client', 'query($o: ID!) { orderTracking(orderId: $o) }', { o: orderId })).orderTracking);
      await scroll('courier', 500);
      await type('courier', 'Code de confirmation', t.otpCode || '0000');
    }
    if (!isPickup && !isCourse && guard % 2 === 1) {
      await scroll('courier', 500);
      await tap('courier', 'Laissé au gardien', { optional: true, timeout: 2000, after: 800 });
    }
    await sleep(800);
    await snap(`point-${next.sequence}-pret`);
    await tap('courier', isPickup ? 'Valider la collecte' : 'Valider la livraison', { after: 2600 });
    await refreshBo();
    if (req.perStop.otp && !clientShown) {
      clientShown = true;
      // La cliente voit la livraison avec ses preuves
      await stage.focus('client');
      await stage.caption('7 · Suivi client', 'Jessica voit immédiatement la livraison et ses preuves (photo, position, code)');
      await reload('client', CLIENT_URL);
      await tap('client', 'Cluny', { after: 2500 });
      await sleep(1500);
      await snap('suivi-livre');
      await scroll('client', 400);
      await sleep(1800);
      await stage.focus('courier');
    }
  }
  await stage.caption('6 · Fin de tournée', 'Tous les points sont traités : Léa clôture sa tournée');
  await tap('courier', 'Terminer la tournée', { after: 1500 });
  await tap('courier', 'Terminer', { exact: true, after: 2500 });
  await snap('tournee-terminee');

  // =====================================================================
  // 8. Exploitation : suivi de tournée
  await stage.focus('web');
  await stage.caption('8 · Traçabilité', 'Chaque point garde son historique, ses preuves et le journal de la tournée');
  await web().evaluate(() => location.reload());
  await sleep(2500);
  await webScroll(500);
  await sleep(2500);
  await webScroll(900);
  await sleep(2000);
  await snap('bo-tournee-finie');

  // 9. Finance : rémunération
  await stage.caption('9 · Rémunération', 'Le gain est calculé au km selon le type de client et le créneau, puis validé par la finance');
  await go('/remuneration', 'Finance');
  await sleep(1500);
  await snap('remuneration');
  await webClick('button:has-text("Détail")', { after: 2500 });
  await snap('remuneration-detail');
  await webClick('.modal button:has-text("Valider"), button.btn:has-text("Valider ")', { after: 2500 });
  const more = await web().locator('button.small:has-text("Valider")').count();
  if (more) await webClick('button.small:has-text("Valider")', { after: 2500 });
  await stage.caption('9 · Rémunération', 'Relevé mensuel par livreur, ajustements tracés, export CSV pour la paie');
  await webScroll(500);
  await sleep(2500);
  await snap('releves');

  // 10. Livreuse : ses gains
  await stage.focus('courier');
  await stage.caption('10 · Gains', 'Léa suit ses gains du mois, tournée par tournée');
  await reload('courier', COURIER_URL);
  await tap('courier', 'Gains', { exact: true, after: 2500 });
  await snap('gains');
  await sleep(2000);

  // 11. Paramétrage
  await stage.focus('web');
  await stage.caption('11 · Paramétrage', 'Grille tarifaire des courses historisée, avec simulateur de prix');
  await go('/tarifs', 'Administration');
  await sleep(2500);
  await snap('tarifs');
  await stage.caption('11 · Paramétrage', 'Profils de preuve : scan, photo, signature, GPS ou code, par type de client, client ou demande');
  await go('/preuves', 'Administration');
  await sleep(3200);
  await stage.caption('11 · Paramétrage', 'Clients : connecteurs d’import, mode d’étiquetage, envoi automatique des étiquettes');
  await go('/clients', 'Administration');
  await sleep(3200);
  await stage.caption('11 · Paramétrage', 'Grilles de rémunération des livreurs : jour, nuit, minimum par tournée, règles de partage');
  await go('/grilles-livreurs', 'Administration');
  await sleep(3200);
  await snap('grilles');

  await stage.overlay(true, 'Wabap V2',
    'Une seule plateforme pour vos clients professionnels, vos particuliers et vos livreurs.',
    ['Import CSV & API', 'Tournées optimisées', 'Étiquettes QR signées', 'Preuves configurables', 'Paiement Stripe', 'Rémunération au km', 'Node.js · Flutter · React · Cognito'],
    'Démonstration sur données fictives');
  await sleep(6000);
  await snap('fin');

  chapters.push({ step: 'Fin', text: 'Conclusion', at: Math.round((Date.now() - t0 - 6000) / 100) / 10 });
  fs.writeFileSync(path.join(OUT, 'chapters.json'), JSON.stringify(chapters, null, 2));
  const video = page.video();
  await ctx.close();
  if (video) console.log(`Vidéo : ${await video.path()}`);
  console.log(errors.length ? errors.join('\n') : 'aucune erreur de page');
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
