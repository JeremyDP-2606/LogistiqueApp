// Lecture des secrets (clés d'API, identifiants) hors du code source.
// La variable d'environnement contient soit la valeur, soit le chemin d'un paramètre SSM
// (c'est ce que crée « amplify update function » > « Configure secret values »).
const AWS = require("aws-sdk");

const cache = {};

async function getSecret(name) {
  if (cache[name]) return cache[name];
  const value = process.env[name];
  if (!value) throw new Error(`Secret manquant : définir ${name} pour cette fonction`);
  if (!value.startsWith("/")) return (cache[name] = value);
  const ssm = new AWS.SSM();
  const { Parameter } = await ssm.getParameter({ Name: value, WithDecryption: true }).promise();
  return (cache[name] = Parameter.Value);
}

module.exports = { getSecret };
