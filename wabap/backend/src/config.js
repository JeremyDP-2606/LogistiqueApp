// Configuration par variables d'environnement (voir .env.example).
const list = (v) => (v ? v.split(',').map((x) => x.trim()).filter(Boolean) : []);
const num = (v, d) => (v === undefined || v === '' ? d : Number(v));

function loadConfig(env = process.env) {
  const c = {
    port: num(env.PORT, 4000),
    publicUrl: (env.PUBLIC_URL || `http://localhost:${num(env.PORT, 4000)}`).replace(/\/$/, ''),
    corsOrigins: list(env.CORS_ORIGINS),
    region: env.AWS_REGION || env.AWS_DEFAULT_REGION || 'us-east-1',
    // Données
    store: env.STORE || 'dynamodb', // dynamodb | memory
    tableSuffix: env.DYNAMODB_TABLE_SUFFIX, // ex. -nfdn7djf2fcbdjz44rvjidtaf4-prod
    dynamoEndpoint: env.DYNAMODB_ENDPOINT, // DynamoDB local
    // Authentification
    authMode: env.AUTH_MODE || 'cognito', // cognito | dev
    userPoolId: env.COGNITO_USER_POOL_ID,
    clientIds: list(env.COGNITO_CLIENT_IDS),
    // Fichiers et e-mails
    bucket: env.S3_BUCKET,
    s3Endpoint: env.S3_ENDPOINT,
    filesDir: env.FILES_DIR || './data/files',
    senderEmail: env.SENDER_EMAIL,
    reportSender: env.REPORT_SENDER || env.SENDER_EMAIL,
    importReportEmails: list(env.IMPORT_REPORT_EMAILS),
    importErrorEmails: list(env.IMPORT_ERROR_EMAILS),
    tourneeReportEmails: list(env.TOURNEE_REPORT_EMAILS),
    // Secrets des services externes
    googleMapsKey: env.GOOGLE_MAPS_API_KEY,
    stripeKey: env.STRIPE_SECRET_KEY,
    labelSecret: env.LABEL_SIGNING_SECRET,
    routexlAuth: env.ROUTEXL_AUTH,
    // Tâches planifiées (une seule instance doit les exécuter)
    schedulerEnabled: env.SCHEDULER_ENABLED !== 'false',
    labelsCron: env.LABELS_CRON || '*/30 * * * *',
    // Imports SFTP planifiés : JSON [{ "cron": "0 5 * * *", "clientName": "...", "host": "...", "port": 22, "username": "...", "password": "...", "filename": "[ABO_]YYYYMMDD[.csv]", "timezone": "America/Martinique" }]
    sftpImports: env.SFTP_IMPORTS ? JSON.parse(env.SFTP_IMPORTS) : [],
    // Règles métier
    business: {
      tzOffsetMinutes: num(env.TZ_OFFSET_MINUTES, -240),
      distanceAlertMeters: num(env.DISTANCE_ALERT_METERS, 200),
      maxAddDetourKm: num(env.MAX_ADD_DETOUR_KM, 3),
    },
    bodyLimit: env.BODY_LIMIT || '25mb',
  };
  const missing = [];
  if (c.store === 'dynamodb' && c.tableSuffix === undefined) missing.push('DYNAMODB_TABLE_SUFFIX');
  if (c.authMode === 'cognito' && !c.userPoolId) missing.push('COGNITO_USER_POOL_ID');
  if (c.authMode === 'dev' && env.NODE_ENV === 'production') throw new Error('AUTH_MODE=dev est interdit en production');
  if (env.NODE_ENV === 'production' && !c.labelSecret) missing.push('LABEL_SIGNING_SECRET');
  if (missing.length) throw new Error(`Configuration incomplète : ${missing.join(', ')}`);
  return c;
}

module.exports = { loadConfig };
