// Configuration du back-office (variables Vite, fichier .env ou .env.production) :
//   VITE_API_URL                 URL de l'API Wabap (ex. https://api.wabap.fr/graphql)
//   VITE_COGNITO_USER_POOL_ID    groupe d'utilisateurs Cognito
//   VITE_COGNITO_CLIENT_ID       application cliente Cognito du back-office
export const config = {
  apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:4000/graphql',
  userPoolId: import.meta.env.VITE_COGNITO_USER_POOL_ID || 'us-east-1_c5SbPwJEZ',
  clientId: import.meta.env.VITE_COGNITO_CLIENT_ID || '1lq36a8msee59bdp7kek0sefsk',
};
