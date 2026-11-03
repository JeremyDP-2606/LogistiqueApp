// Étiquettes PDF au format standard 100 × 150 mm (spec §4.2) : une étiquette par page.
const { PDFDocument, StandardFonts, rgb } = require('pdf-lib');
const QRCode = require('qrcode');
const bwipjs = require('bwip-js');

const MM = 72 / 25.4;
const W = 100 * MM;
const H = 150 * MM;
const INK = rgb(0, 0, 0);
const GREY = rgb(0.35, 0.35, 0.35);

// Les polices standard du PDF ne couvrent que le jeu WinAnsi : on remplace les quelques caractères hors jeu
const safe = (s) => String(s ?? '').replace(/[’‘]/g, "'").replace(/[“”]/g, '"').replace(/[–—]/g, '-').replace(/ /g, ' ')
  .replace(/[^\x20-\x7E\xA0-\xFF€]/g, '');

function wrap(text, font, size, maxWidth) {
  const words = safe(text).split(/\s+/).filter(Boolean);
  const lines = [];
  let line = '';
  for (const w of words) {
    const tryLine = line ? `${line} ${w}` : w;
    if (font.widthOfTextAtSize(tryLine, size) <= maxWidth) line = tryLine;
    else { if (line) lines.push(line); line = w; }
  }
  if (line) lines.push(line);
  return lines;
}

function hhmmLocal(iso, tzOffsetMin) {
  const d = new Date(new Date(iso).getTime() + tzOffsetMin * 60000);
  return `${String(d.getUTCDate()).padStart(2, '0')}/${String(d.getUTCMonth() + 1).padStart(2, '0')} ${String(d.getUTCHours()).padStart(2, '0')}:${String(d.getUTCMinutes()).padStart(2, '0')}`;
}

/**
 * @param labels [{ code, parcelId, customerName, reserved, index, total, orderRef, tourRef,
 *                  recipient: { name, phone, address }, deadlineAt, fragile, instructions }]
 * @returns Uint8Array (PDF)
 */
async function renderLabels(labels, { tzOffsetMinutes = -240 } = {}) {
  const pdf = await PDFDocument.create();
  pdf.setTitle('Étiquettes Wabap');
  pdf.setCreator('Wabap');
  const bold = await pdf.embedFont(StandardFonts.HelveticaBold);
  const regular = await pdf.embedFont(StandardFonts.Helvetica);

  for (const l of labels) {
    const page = pdf.addPage([W, H]);
    const m = 6 * MM;
    let y = H - m;

    // En-tête : marque et client donneur d'ordre
    page.drawRectangle({ x: 0, y: H - 16 * MM, width: W, height: 16 * MM, color: INK });
    page.drawText('WABAP', { x: m, y: H - 11 * MM, size: 16, font: bold, color: rgb(1, 1, 1) });
    const client = safe(l.customerName || '');
    page.drawText(client, { x: W - m - bold.widthOfTextAtSize(client, 10), y: H - 10.5 * MM, size: 10, font: bold, color: rgb(1, 1, 1) });
    y = H - 22 * MM;

    if (l.reserved) {
      page.drawText('ÉTIQUETTE EN RÉSERVE', { x: m, y, size: 15, font: bold });
      y -= 8 * MM;
      for (const line of wrap('À coller sur un colis remis à la collecte. Elle devient un colis au premier scan du livreur.', regular, 9, W - 2 * m)) {
        page.drawText(line, { x: m, y, size: 9, font: regular, color: GREY });
        y -= 4.5 * MM;
      }
      if (l.tourRef) { page.drawText(safe(`Tournée ${l.tourRef}`), { x: m, y: y - 2 * MM, size: 10, font: bold }); }
    } else {
      page.drawText('LIVRER À', { x: m, y, size: 8, font: bold, color: GREY });
      y -= 6 * MM;
      for (const line of wrap(l.recipient?.name || '', bold, 14, W - 2 * m).slice(0, 2)) { page.drawText(line, { x: m, y, size: 14, font: bold }); y -= 6 * MM; }
      for (const line of wrap(l.recipient?.address || '', regular, 11, W - 2 * m).slice(0, 3)) { page.drawText(line, { x: m, y, size: 11, font: regular }); y -= 5 * MM; }
      if (l.recipient?.phone) { page.drawText(safe(l.recipient.phone), { x: m, y, size: 10, font: regular, color: GREY }); y -= 5 * MM; }
      if (l.instructions) { for (const line of wrap(l.instructions, regular, 8, W - 2 * m).slice(0, 2)) { page.drawText(line, { x: m, y, size: 8, font: regular, color: GREY }); y -= 4 * MM; } }
    }

    // Mentions spéciales et numéro de colis
    const badges = [];
    if (l.deadlineAt) badges.push(`AVANT ${hhmmLocal(l.deadlineAt, tzOffsetMinutes)}`);
    if (l.fragile) badges.push('FRAGILE');
    let bx = m;
    const by = 62 * MM;
    for (const b of badges) {
      const bw = bold.widthOfTextAtSize(b, 11) + 4 * MM;
      page.drawRectangle({ x: bx, y: by, width: bw, height: 8 * MM, borderColor: INK, borderWidth: 1.5 });
      page.drawText(b, { x: bx + 2 * MM, y: by + 2.5 * MM, size: 11, font: bold });
      bx += bw + 3 * MM;
    }
    if (!l.reserved && l.total) {
      const n = `${l.index}/${l.total}`;
      page.drawText(n, { x: W - m - bold.widthOfTextAtSize(n, 22), y: by + 1 * MM, size: 22, font: bold });
    }

    // QR code (code complet signé)
    const qr = await QRCode.toBuffer(l.code, { errorCorrectionLevel: 'M', margin: 0, width: 400 });
    const qrImg = await pdf.embedPng(qr);
    const qs = 34 * MM;
    page.drawImage(qrImg, { x: m, y: 22 * MM, width: qs, height: qs });
    const info = [l.orderRef ? `Demande ${l.orderRef}` : null, l.tourRef ? `Tournée ${l.tourRef}` : null, `Colis ${l.parcelId}`].filter(Boolean);
    let iy = 50 * MM;
    for (const t of info) { page.drawText(safe(t), { x: m + qs + 4 * MM, y: iy, size: 9, font: regular }); iy -= 5 * MM; }

    // Code-barres Code 128 du même code
    const bar = await bwipjs.toBuffer({ bcid: 'code128', text: l.code, scale: 3, height: 10, includetext: false });
    const barImg = await pdf.embedPng(bar);
    const bw = W - 2 * m;
    page.drawImage(barImg, { x: m, y: 7 * MM, width: bw, height: 12 * MM });
    const codeText = safe(l.code);
    page.drawText(codeText, { x: (W - regular.widthOfTextAtSize(codeText, 7)) / 2, y: 3.5 * MM, size: 7, font: regular });
  }
  return pdf.save();
}

module.exports = { renderLabels, W, H };
