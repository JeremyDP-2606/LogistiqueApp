// Accès à l'API Wabap : GraphQL (HTTP), abonnements temps réel (WebSocket, protocole graphql-ws)
// et routes REST /v1. API.graphql(graphqlOperation(...)) garde la forme utilisée par les écrans :
// promesse { data } (rejet { data, errors } en cas d'erreur) ou, pour un abonnement, un objet
// .subscribe({ next, error }) dont next reçoit { value: { data } }.
import { createClient } from "graphql-ws";
import { config, restUrl } from "@/config";
import { idToken } from "@/util/cognito";

export const graphqlOperation = (query, variables = {}) => ({ query, variables });

let wsClient = null;
function realtime() {
  if (!wsClient) {
    wsClient = createClient({
      url: config.apiUrl.replace(/^http/, "ws"),
      connectionParams: async () => ({ Authorization: await idToken() }),
      retryAttempts: Infinity,
      shouldRetry: () => true,
      lazy: true,
    });
  }
  return wsClient;
}

async function request(query, variables) {
  const token = await idToken();
  if (!token) throw { errors: [{ message: "Session expirée : reconnectez-vous" }] };
  const res = await fetch(config.apiUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: token },
    body: JSON.stringify({ query, variables }),
  });
  const body = await res.json().catch(() => ({ errors: [{ message: `Erreur ${res.status}` }] }));
  if (body.errors?.length || !res.ok) throw { data: body.data, errors: body.errors || [{ message: `Erreur ${res.status}` }] };
  return { data: body.data };
}

export const API = {
  graphql({ query, variables }) {
    if (/^\s*subscription\b/.test(query)) {
      return {
        subscribe({ next, error }) {
          const dispose = realtime().subscribe({ query, variables }, {
            next: (result) => (result.errors ? error?.(result) : next?.({ value: { data: result.data } })),
            error: (e) => error?.(e),
            complete: () => {},
          });
          return { unsubscribe: dispose };
        },
      };
    }
    return request(query, variables);
  },
};

// Routes REST du serveur (/v1/...) avec le jeton de session
export async function rest(method, path, body) {
  const token = await idToken();
  const res = await fetch(`${restUrl}/v1${path}`, {
    method,
    headers: { "Content-Type": "application/json", ...(token ? { Authorization: token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error || `Erreur ${res.status}`);
  return data;
}
