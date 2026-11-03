// Lecture des secrets (clés d'API, identifiants) hors du code source.
// La variable d'environnement contient soit la valeur, soit le chemin d'un paramètre SSM
// (c'est ce que crée « amplify update function » > « Configure secret values »).
// SDK v3 fourni par le runtime Node.js 24 (chargé seulement si un secret est stocké dans SSM)

const cache = {};

async function getSecret(name) {
  if (cache[name]) return cache[name];
  const value = process.env[name];
  if (!value) throw new Error(`Secret manquant : définir ${name} pour cette fonction`);
  if (!value.startsWith("/")) return (cache[name] = value);
  const { SSMClient, GetParameterCommand } = require("@aws-sdk/client-ssm");
  const ssm = new SSMClient({ region: process.env.REGION });
  const { Parameter } = await ssm.send(new GetParameterCommand({ Name: value, WithDecryption: true }));
  return (cache[name] = Parameter.Value);
}

module.exports = { getSecret };
