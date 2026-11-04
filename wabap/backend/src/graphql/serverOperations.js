// Opérations du schéma traitées par le serveur lui-même (et non par les opérations métier src/delivery).
const crypto = require('crypto');

const EXT = { 'image/jpeg': 'jpg', 'image/jpg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/heic': 'heic', 'application/pdf': 'pdf' };

function createServerOperations({ files, v1 }) {
  return {
    // Rapport de fin de tournée V1
    invokeLambdaRapportTournee: ({ input }, ctx) => v1.rapport.generate(input, ctx.identity),
    // Lien d'envoi direct vers le stockage (remplace l'envoi Amplify Storage de l'app)
    async createUploadUrl({ kind, contentType, tourId, key: v1Key }, ctx) {
      const ext = EXT[contentType];
      if (!ext) throw new Error(`Type de fichier non accepté : ${contentType}`);
      // Preuves V1 : même emplacement qu'avec Amplify Storage (niveau public) : public/tournee_<id>/<fichier>
      if (v1Key) {
        if (!/^tournee_[A-Za-z0-9-]+\/[A-Za-z0-9._-]+$/.test(v1Key)) throw new Error('Clé de preuve invalide');
        return files.createUploadUrl({ key: `public/${v1Key}`, contentType });
      }
      const safeKind = String(kind).replace(/[^a-z0-9_-]/gi, '').slice(0, 30) || 'preuve';
      const key = `proofs/${ctx.identity.sub}/${tourId ? `${String(tourId).replace(/[^a-z0-9-]/gi, '')}/` : ''}${safeKind}-${crypto.randomUUID()}.${ext}`;
      return files.createUploadUrl({ key, contentType });
    },
  };
}

// Noms des opérations traitées ici (le test de cohérence du schéma les exclut des opérations métier)
const SERVER_OPERATIONS = { createUploadUrl: true, invokeLambdaRapportTournee: true };

module.exports = { createServerOperations, SERVER_OPERATIONS };
