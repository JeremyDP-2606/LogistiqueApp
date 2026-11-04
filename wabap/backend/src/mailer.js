// Envoi d'e-mails : Amazon SES en production, console en développement.
// send({ to: [..], subject, text, from?, attachments?: [{ filename, content | key }] })
function createSesMailer({ region, from, files }) {
  const { SESClient, SendRawEmailCommand } = require('@aws-sdk/client-ses');
  const ses = new SESClient({ region });
  const b64 = (s) => Buffer.from(s, 'utf8').toString('base64');
  return {
    async send({ to, subject, text, attachments = [], from: sender }) {
      const boundary = `wabap-${Date.now()}`;
      const parts = [
        `From: ${sender || from}`, `To: ${to.join(', ')}`, `Subject: =?UTF-8?B?${b64(subject)}?=`, 'MIME-Version: 1.0',
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

function createConsoleMailer({ log = console } = {}) {
  return {
    sent: [],
    async send(m) {
      this.sent.push(m);
      log.log(`[e-mail simulé] ${m.to.join(', ')} : ${m.subject}`);
    },
  };
}

module.exports = { createSesMailer, createConsoleMailer };
