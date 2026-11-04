// Affiche l'API GraphQL compilée depuis schema/schema.graphql (npm run schema → schema/api.graphql).
const fs = require('fs');
const { printSchema, buildSchema } = require('graphql');
const { compileSchema } = require('../src/schema/compile');
const { SCHEMA_FILE } = require('../src/services');

const { sdl } = compileSchema(fs.readFileSync(SCHEMA_FILE, 'utf8'));
process.stdout.write(`# API GraphQL Wabap : fichier généré par « npm run schema » depuis schema/schema.graphql, ne pas modifier.\n\n${printSchema(buildSchema(sdl))}\n`);
