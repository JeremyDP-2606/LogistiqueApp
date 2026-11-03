// Services AWS : fichiers (S3, liens temporaires) et e-mails (SES). SDK v3 fourni par le runtime Lambda.
function createFiles({ bucket, region }) {
  const { S3Client, PutObjectCommand, GetObjectCommand } = require('@aws-sdk/client-s3');
  const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');
  const s3 = new S3Client({ region });
  return {
    s3,
    // Les étiquettes contiennent des adresses : fichiers privés, lien valable 15 minutes
    async put(key, bytes, contentType) {
      await s3.send(new PutObjectCommand({ Bucket: bucket, Key: `private-labels/${key}`, Body: bytes, ContentType: contentType }));
      const url = await getSignedUrl(s3, new GetObjectCommand({ Bucket: bucket, Key: `private-labels/${key}` }), { expiresIn: 900 });
      return { key: `private-labels/${key}`, url };
    },
    async get(key) {
      const r = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
      return Buffer.from(await r.Body.transformToByteArray());
    },
  };
}

function createMailer({ region, from, files }) {
  const { SESClient, SendRawEmailCommand } = require('@aws-sdk/client-ses');
  const ses = new SESClient({ region });
  const b64 = (s) => Buffer.from(s, 'utf8').toString('base64');
  return {
    async send({ to, subject, text, attachments = [] }) {
      const boundary = `wabap-${Date.now()}`;
      const parts = [
        `From: ${from}`, `To: ${to.join(', ')}`, `Subject: =?UTF-8?B?${b64(subject)}?=`, 'MIME-Version: 1.0',
        `Content-Type: multipart/mixed; boundary="${boundary}"`, '',
        `--${boundary}`, 'Content-Type: text/plain; charset=UTF-8', 'Content-Transfer-Encoding: base64', '', b64(text),
      ];
      for (const a of attachments) {
        const content = a.content || await files.get(a.key);
        parts.push(`--${boundary}`, `Content-Type: application/pdf; name="${a.filename}"`, 'Content-Transfer-Encoding: base64',
          `Content-Disposition: attachment; filename="${a.filename}"`, '', Buffer.from(content).toString('base64'));
      }
      parts.push(`--${boundary}--`);
      await ses.send(new SendRawEmailCommand({ RawMessage: { Data: Buffer.from(parts.join('\r\n')) } }));
    },
  };
}

module.exports = { createFiles, createMailer };
