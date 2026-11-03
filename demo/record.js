// Enregistre une vidéo de démonstration du parcours complet.
// Prérequis (voir demo/README.md) : API sur :4000 (base de démo fraîche), app Flutter web servie sur :8081 et :8082,
// front React sur :5173.
//   node demo/record.js <dossier-de-sortie> [--debug]
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const OUT = path.resolve(process.argv[2] || 'demo-output');
const DEBUG = process.argv.includes('--debug');
const API = 'http://localhost:4000/api';
const CLIENT_APP = 'http://localhost:8081/';
const COURIER_APP = 'http://localhost:8082/';
const WEB = 'http://localhost:5173';
const TILE = fs.readFileSync(path.join(__dirname, 'assets', 'tile.png'));

// Le bac à sable n'a pas accès à OpenStreetMap : recherche d'adresse simulée avec de vraies coordonnées.
const ADDRESSES = [
  { address: '12 Rue Montorgueil, 75002 Paris', lat: 48.8645, lng: 2.3470 },
  { address: '40 Boulevard Voltaire, 75011 Paris', lat: 48.8610, lng: 2.3720 },
  { address: '12 Rue Montmartre, 75001 Paris', lat: 48.8636, lng: 2.3454 },
  { address: '40 Rue Voltaire, 93100 Montreuil', lat: 48.8571, lng: 2.4390 },
];
const COURIER_START = { latitude: 48.8668, longitude: 2.3395 };

const T0 = Date.now();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
fs.mkdirSync(OUT, { recursive: true });

async function api(method, p, body, token) {
  const res = await fetch(API + p, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return res.json();
}

(async () => {
  const browser = await chromium.launch();
  const context = await browser.newContext({
    viewport: { width: 1920, height: 1080 },
    ...(DEBUG ? {} : { recordVideo: { dir: OUT, size: { width: 1920, height: 1080 } } }),
    geolocation: COURIER_START,
    permissions: ['geolocation'],
    locale: 'fr-FR',
  });
  await context.route(/tile\.openstreetmap\.org/, (route) =>
    route.fulfill({ status: 200, contentType: 'image/png', body: TILE, headers: { 'Access-Control-Allow-Origin': '*', 'Cache-Control': 'no-store' } }));
  await context.route(/\/api\/geo\/search/, (route) => {
    const q = new URL(route.request().url()).searchParams.get('q').toLowerCase();
    const words = q.split(/\s+/).filter((w) => w.length > 2);
    const results = ADDRESSES.filter((a) => words.some((w) => a.address.toLowerCase().includes(w)));
    route.fulfill({ status: 200, contentType: 'application/json', headers: { 'Access-Control-Allow-Origin': '*' }, body: JSON.stringify({ results }) });
  });

  const page = await context.newPage();
  global.__page = page;
  page.on('pageerror', (e) => console.log('pageerror', (e.stack || e.message).slice(0, 160).replace(/\n/g, ' ')));
  if (DEBUG) {
    page.on('console', (m) => { if (m.type() === 'error') console.log('console', m.frame()?.name(), m.text().slice(0, 200)); });
    page.on('requestfailed', (r) => console.log('reqfailed', r.frame()?.name(), r.url().replace(/\/\d+\.png$/, ''), r.failure()?.errorText));
    page.on('request', (r) => { if (/tile/.test(r.url()) && r.frame()?.name() === 'courier') console.log('REQ', ((Date.now() - T0) / 1000).toFixed(1), r.url().slice(-20)); });
    page.on('requestfailed', (r) => { if (/tile/.test(r.url())) console.log('FAIL', ((Date.now() - T0) / 1000).toFixed(1), r.url().slice(-20)); });
    page.on('requestfinished', (r) => { if (/tile/.test(r.url())) console.log('tileok', r.frame()?.name(), r.url().replace(/\/\d+\/\d+\.png$/, '')); });
  }
  await page.goto('file://' + path.join(__dirname, 'stage.html'));
  const d = (fn, ...args) => (DEBUG && fn === 'caption' && console.log('STEP', ((Date.now() - T0) / 1000).toFixed(1), args.join(' ')), page.evaluate(({ fn, args }) => window.demo[fn](...args), { fn, args }));
  let shot = 0;
  const snap = async (name) => { if (DEBUG) await page.screenshot({ path: path.join(OUT, `${String(++shot).padStart(2, '0')}-${name}.png`) }); };

  const frames = {};
  async function loadFrame(id, url) {
    await page.evaluate(({ id, url }) => { document.getElementById(id).src = url; }, { id, url });
    await sleep(300);
    frames[id] = page.frame({ name: id });
    return frames[id];
  }
  async function enableSemantics(f) {
    await f.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 30000 });
    await f.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
    await sleep(600);
  }
  // Flutter : tape sur l'élément d'accessibilité le plus profond qui contient le texte
  async function tap(f, text, { exact = false, nth } = {}) {
    const loc = exact
      ? f.locator('flt-semantics').filter({ hasText: new RegExp(`^${text}$`) })
      : f.locator(`flt-semantics:has-text("${text}"), flt-semantics[aria-label*="${text}"]`);
    for (let attempt = 0; attempt < 8; attempt++) {
      try { await loc.first().waitFor({ state: 'attached', timeout: 2500 }); break; } catch (e) {
        if (attempt === 7) throw e;
        await jiggle(f);
      }
    }
    const target = nth !== undefined ? loc.nth(nth) : loc.last();
    // Uniquement l'action d'accessibilité (un vrai clic souris traverserait vers l'écran suivant)
    await target.evaluate((el) => el.click());
    await sleep(700);
  }
  // Petit mouvement de souris sur l'iframe : force Flutter à rafraîchir son arbre d'accessibilité
  async function jiggle(f) {
    const box = await page.locator(`#${f.name()}`).boundingBox();
    await page.mouse.move(box.x + 30 + Math.random() * 20, box.y + box.height - 40);
    await page.mouse.move(box.x + 60, box.y + box.height - 60, { steps: 4 });
    await sleep(400);
  }
  async function type(f, label, text, nth = 0) {
    // Un champ Flutter peut être momentanément absent de l'arbre d'accessibilité : on réessaie
    const sel = `input[aria-label="${label}"], textarea[aria-label="${label}"]`;
    let input;
    for (let attempt = 0; attempt < 8; attempt++) {
      input = f.locator(sel).nth(nth);
      try { await input.waitFor({ state: 'attached', timeout: 2500 }); break; } catch (e) {
        if (attempt === 7) throw e;
        await jiggle(f);
      }
    }
    await input.focus();
    await sleep(350);
    await page.keyboard.type(text, { delay: 55 });
    await sleep(300);
  }
  async function scroll(id, dy) {
    const box = await page.locator(`#${id}`).boundingBox();
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2);
    for (let i = 0; i < Math.abs(dy) / 100; i++) { await page.mouse.wheel(0, Math.sign(dy) * 100); await sleep(60); }
    await sleep(600);
  }
  async function moveCourier(from, to, steps = 10, delay = 700) {
    for (let i = 1; i <= steps; i++) {
      const t = i / steps;
      await context.setGeolocation({ latitude: from.lat + (to.lat - from.lat) * t, longitude: from.lng + (to.lng - from.lng) * t });
      await sleep(delay);
    }
  }
  async function webLogin(email) {
    const w = await loadFrame('web', `${WEB}/login`);
    await w.waitForSelector('input[type=email]');
    await w.fill('input[type=email]', '');
    await w.locator('input[type=email]').pressSequentially(email, { delay: 40 });
    await w.locator('input[type=password]').pressSequentially('demo1234', { delay: 40 });
    await w.locator('input[type=password]').press('Enter');
    await sleep(1500);
    return w;
  }

  // ---------- Intro ----------
  await d('overlay', true, 'LogistiqueApp', 'Plateforme de livraison urbaine du dernier kilomètre<br>Démo du parcours complet : commande, dispatch, suivi en direct, remise sécurisée');
  const client = await loadFrame('client', CLIENT_APP);
  const courier = await loadFrame('courier', COURIER_APP);
  await enableSemantics(client);
  await enableSemantics(courier);
  await webLogin('client@demo.fr');
  await page.evaluate(() => { document.getElementById('web').contentWindow; });
  await sleep(DEBUG ? 500 : 4000);
  await d('overlay', false);
  await sleep(800);
  await snap('stage');

  // ---------- 1. Le coursier se connecte et passe en ligne ----------
  await d('caption', '1 · Coursier', 'Léa, coursière à vélo, se connecte à l’app et passe en ligne');
  await d('focus', 'courier');
  await type(courier, 'Email', 'velo@demo.fr');
  await type(courier, 'Mot de passe', 'demo1234');
  await tap(courier, 'Se connecter');
  await sleep(1500);
  await snap('courier-logged');
  await tap(courier, 'Vous êtes hors ligne');
  await sleep(2000);
  await snap('courier-online');

  // ---------- 2. Le client commande ----------
  await d('caption', '2 · Client', 'Une boulangerie se connecte et crée une nouvelle livraison');
  await d('focus', 'client');
  await type(client, 'Email', 'client@demo.fr');
  await type(client, 'Mot de passe', 'demo1234');
  await tap(client, 'Se connecter');
  await sleep(1500);
  await tap(client, 'Nouvelle livraison');
  await sleep(1200);
  await snap('client-new');

  await d('caption', '2 · Client', 'Adresse de retrait avec autocomplétion');
  await tap(client, 'Où récupérer le colis ?');
  await type(client, 'Rechercher une adresse', 'rue Montorgueil');
  await sleep(1200);
  await snap('client-search');
  await tap(client, '12 Rue Montorgueil, 75002 Paris');
  await sleep(2000);
  await type(client, 'Contact', 'Boulangerie Martin', 0);
  await type(client, 'Téléphone', '06 11 22 33 44', 0);

  await d('caption', '2 · Client', 'Adresse de livraison, contact du destinataire et instructions');
  await tap(client, 'Où le livrer ?');
  await type(client, 'Rechercher une adresse', 'boulevard Voltaire');
  await sleep(1200);
  await tap(client, '40 Boulevard Voltaire, 75011 Paris');
  await sleep(2000);
  await snap('client-addresses');
  await scroll('client', 300);
  await type(client, 'Contact', 'Alice Dupont', 1);
  await type(client, 'Téléphone', '06 07 08 09 10', 1);
  await type(client, 'Instructions (étage, code…)', '3e étage, code 4521', 1);
  await scroll('client', 400);
  await snap('client-size');

  await d('caption', '2 · Client', 'Taille du colis, délai express et devis instantané par véhicule');
  await type(client, 'Description du colis (optionnel)', 'Gâteau d’anniversaire');
  await tap(client, 'Express · 45 min');
  await sleep(1200);
  await scroll('client', 500);
  await sleep(800);
  await snap('client-quote');
  await d('caption', '2 · Client', 'Le prix TTC s’affiche immédiatement : on commande');
  await sleep(1500);
  await tap(client, 'Commander');
  await sleep(2000);
  await snap('client-ordered');

  // ---------- 3. Dispatch temps réel ----------
  const ct = (await api('POST', '/auth/login', { email: 'client@demo.fr', password: 'demo1234' })).token;
  const job = (await api('GET', '/jobs', null, ct)).jobs[0];
  console.log('job', job.ref, job.deliveryCode);

  await d('caption', '3 · Temps réel', 'La course arrive instantanément chez les coursiers proches, avec leur rémunération');
  await d('focus', 'courier');
  await sleep(2500);
  await snap('courier-newjob');

  await d('caption', '3 · Temps réel', 'Côté web, le client suit la même course depuis son ordinateur');
  await d('web', 'Espace client', `logistiqueapp.local/jobs/${job.ref}`);
  const web = await loadFrame('web', `${WEB}/jobs/${job.id}`);
  await web.waitForSelector('.code');
  await d('focus', 'web');
  await sleep(2500);

  await d('caption', '4 · Coursier', 'Léa accepte la course');
  await d('focus', 'courier');
  await tap(courier, 'Accepter');
  await sleep(2500);
  await snap('courier-accepted');

  await d('caption', '4 · Coursier', 'Le client voit le coursier assigné, sa note et peut l’appeler');
  await d('focus', 'client');
  await sleep(2500);

  // ---------- 5. Retrait ----------
  await d('caption', '5 · Retrait', 'En route vers le retrait : sa position est suivie en direct');
  await d('focus', 'courier');
  await tap(courier, 'Je pars vers le retrait');
  await d('focus', 'web');
  await moveCourier({ lat: COURIER_START.latitude, lng: COURIER_START.longitude }, ADDRESSES[0], 8, 650);
  await snap('moving-pickup');
  await d('caption', '5 · Retrait', 'Arrivée à la boulangerie : colis récupéré');
  await d('focus', 'courier');
  await tap(courier, 'Colis récupéré');
  await sleep(1500);

  // ---------- 6. Livraison ----------
  await d('caption', '6 · Livraison', 'En cours de livraison : client et site web reçoivent chaque étape');
  await tap(courier, 'Je pars livrer');
  await d('focus', 'client');
  await moveCourier(ADDRESSES[0], ADDRESSES[1], 12, 650);
  await snap('moving-dropoff');

  await d('caption', '6 · Livraison', 'Le code de remise est connu seulement du client et du destinataire');
  await d('focus', 'web');
  await sleep(2500);

  await d('caption', '7 · Remise', `Le destinataire donne son code (${job.deliveryCode}), Léa le saisit pour valider`);
  await d('focus', 'courier');
  await tap(courier, 'Valider la livraison');
  await sleep(800);
  await page.keyboard.type(job.deliveryCode, { delay: 250 });
  await sleep(600);
  await snap('code');
  await tap(courier, 'Valider', { exact: true });
  await sleep(2500);
  await snap('delivered');
  await tap(courier, 'OK', { exact: true });
  await sleep(1000);

  // ---------- 8. Notation ----------
  await d('caption', '8 · Avis', 'La livraison est terminée : le client note sa coursière');
  await d('focus', 'client');
  await scroll('client', 1500);
  await tap(client, 'Noter la livraison');
  await sleep(800);
  await type(client, 'Commentaire (optionnel)', 'Rapide et très aimable, merci !');
  await snap('rating');
  await tap(client, 'Envoyer');
  await sleep(1800);

  await d('caption', '8 · Gains', 'Côté coursier : gains du jour, de la semaine et historique');
  await d('focus', 'courier');
  await tap(courier, 'Gains');
  await sleep(2500);
  await snap('earnings');

  // ---------- 9. Admin ----------
  await d('caption', '9 · Exploitation', 'Console admin : indicateurs, flotte en ligne et statut des coursiers');
  await d('web', 'Console admin', 'logistiqueapp.local/admin');
  await d('focus', 'web');
  const w2 = await loadFrame('web', `${WEB}/`);
  await w2.waitForSelector('button.link');
  await w2.evaluate(() => document.querySelector('button.link').click());
  await webLogin('admin@demo.fr');
  await sleep(3500);
  await snap('admin');

  // ---------- Outro ----------
  await d('focus', 'none');
  await d('overlay', true, 'LogistiqueApp',
    'Application mobile Flutter (client et coursier) · API Node.js temps réel · Site web React<br>Devis instantané · Dispatch en direct · Suivi GPS · Code de remise · Gains · Console admin');
  await sleep(DEBUG ? 500 : 5000);

  const video = page.video();
  await context.close();
  if (video) console.log('video', await video.path());
  await browser.close();
})().catch(async (e) => {
  if (DEBUG && global.__page) await global.__page.screenshot({ path: path.join(OUT, 'zz-error.png') }).catch(() => {}); console.error(String(e).split('\n').slice(0, 4).join(' | ')); process.exit(1); });
