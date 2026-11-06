// Firebase Cloud Messaging desde el Worker, sin SDK: OAuth con JWT RS256 firmado
// con WebCrypto usando la service account (secret FCM_SA, JSON). Nunca se
// registran tokens de dispositivo en logs.

let cache = { token: null, exp: 0 };

const b64url = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf)))
  .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
const b64urlTxt = (s) => b64url(new TextEncoder().encode(s));

function pemABytes(pem) {
  const b = atob(pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, ""));
  return Uint8Array.from(b, (c) => c.charCodeAt(0));
}

export function cuentaServicio(env) {
  if (!env || !env.FCM_SA) throw new Error("falta el secret FCM_SA");
  return JSON.parse(env.FCM_SA);
}

export async function tokenOAuth(env, fetchFn = fetch, ahora = Date.now()) {
  if (cache.token && cache.exp - 60_000 > ahora) return cache.token;
  const sa = cuentaServicio(env);
  const iat = Math.floor(ahora / 1000);
  const header = b64urlTxt(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = b64urlTxt(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat, exp: iat + 3600,
  }));
  const key = await crypto.subtle.importKey("pkcs8", pemABytes(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"]);
  const firma = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(`${header}.${claims}`));
  const r = await fetchFn("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: `${header}.${claims}.${b64url(firma)}`,
    }),
  });
  const j = await r.json();
  if (!j.access_token) throw new Error(`oauth ${r.status}`);
  cache = { token: j.access_token, exp: ahora + j.expires_in * 1000 };
  return cache.token;
}

/** Envía una notificación web a un tema. Devuelve true/false (sin lanzar). */
export async function enviarATema(env, { tema, titulo, cuerpo }, fetchFn = fetch) {
  const sa = cuentaServicio(env);
  const t = await tokenOAuth(env, fetchFn);
  const r = await fetchFn(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${t}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        topic: tema,
        webpush: {
          notification: { title: titulo, body: cuerpo, icon: "/icons/Icon-192.png", badge: "/icons/Icon-192.png", lang: "es-PA" },
          fcm_options: { link: "https://cuandopagan.3qbic.com/" },
        },
      },
    }),
  });
  return r.ok;
}

/** Suscribe (alta) o desuscribe (baja) un token a varios temas. */
export async function gestionarTemas(env, token, temas, alta, fetchFn = fetch) {
  const t = await tokenOAuth(env, fetchFn);
  const url = `https://iid.googleapis.com/iid/v1:${alta ? "batchAdd" : "batchRemove"}`;
  let ok = true;
  for (const tema of temas) {
    const r = await fetchFn(url, {
      method: "POST",
      headers: { Authorization: `Bearer ${t}`, "Content-Type": "application/json", access_token_auth: "true" },
      body: JSON.stringify({ to: `/topics/${tema}`, registration_tokens: [token] }),
    });
    ok = ok && r.ok;
  }
  return ok;
}

export function _resetCache() { cache = { token: null, exp: 0 }; }
