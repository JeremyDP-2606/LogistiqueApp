// Fichiers (étiquettes PDF, preuves photo et signature) : S3 en production, dossier local en développement.
// Interface : put(key, bytes, contentType) → { key, url } · get(key) · getUrl(key) · createUploadUrl({ key, contentType })
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

function createS3Files({ bucket, region, endpoint }) {
  const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
  const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
  const s3 = new S3Client({ region, ...(endpoint ? { endpoint, forcePathStyle: true } : {}) });
  const getUrl = (key, expiresIn = 900) => getSignedUrl(s3, new GetObjectCommand({ Bucket: bucket, Key: key }), { expiresIn });
  return {
    // Les étiquettes contiennent des adresses : fichiers privés, lien valable 15 minutes
    async put(key, bytes, contentType) {
      const k = key.startsWith('private-') || key.startsWith('proofs/') ? key : `private-labels/${key}`;
      await s3.send(new PutObjectCommand({ Bucket: bucket, Key: k, Body: bytes, ContentType: contentType }));
      return { key: k, url: await getUrl(k) };
    },
    async get(key) {
      const r = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      return Buffer.from(await r.Body.transformToByteArray());
    },
    getUrl,
    async createUploadUrl({ key, contentType }) {
      const url = await getSignedUrl(s3, new PutObjectCommand({ Bucket: bucket, Key: key, ContentType: contentType }), { expiresIn: 600 });
      return { key, url, method: 'PUT', headers: { 'Content-Type': contentType } };
    },
  };
}

// Développement : fichiers dans un dossier, servis par le serveur (routes /files, voir src/app.js)
function createLocalFiles({ dir, publicUrl }) {
  fs.mkdirSync(dir, { recursive: true });
  const base = () => (typeof publicUrl === 'function' ? publicUrl() : publicUrl);
  const tokens = new Map(); // jeton d'envoi → clé
  const safe = (key) => {
    const p = path.resolve(dir, key);
    if (!p.startsWith(path.resolve(dir) + path.sep)) throw new Error('Clé de fichier invalide');
    return p;
  };
  return {
    dir,
    async put(key, bytes) {
      const k = key.startsWith('private-') || key.startsWith('proofs/') ? key : `private-labels/${key}`;
      fs.mkdirSync(path.dirname(safe(k)), { recursive: true });
      fs.writeFileSync(safe(k), Buffer.from(bytes));
      return { key: k, url: `${base()}/files/${encodeURIComponent(k)}` };
    },
    async get(key) { return fs.readFileSync(safe(key)); },
    async getUrl(key) { return `${base()}/files/${encodeURIComponent(key)}`; },
    async createUploadUrl({ key, contentType }) {
      const token = crypto.randomBytes(16).toString('hex');
      tokens.set(token, key);
      setTimeout(() => tokens.delete(token), 600_000).unref();
      return { key, url: `${base()}/files/upload/${token}`, method: 'PUT', headers: { 'Content-Type': contentType } };
    },
    // Réception d'un envoi par lien temporaire (dev)
    async receive(token, bytes) {
      const key = tokens.get(token);
      if (!key) return null;
      tokens.delete(token);
      fs.mkdirSync(path.dirname(safe(key)), { recursive: true });
      fs.writeFileSync(safe(key), bytes);
      return key;
    },
    path: safe,
  };
}

module.exports = { createS3Files, createLocalFiles };
