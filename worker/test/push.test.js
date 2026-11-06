import { test } from "node:test";
import assert from "node:assert/strict";
import { validarPeticion, manejarPush } from "../src/push/rutas.js";
import { enviarATema, gestionarTemas, _resetCache } from "../src/push/fcm.js";

const TOKEN = "f".repeat(40) + ":APA91b" + "x".repeat(120);

test("valida alta correcta y arma los temas", () => {
  const v = validarPeticion({ token: TOKEN, categoria: "GRUPO 3", anticipaciones: [1, 0, 1] });
  assert.equal(v.ok, true);
  assert.deepEqual(v.temas, ["grupo3-d1", "grupo3-d0"]);
});

test("rechaza token, categoría o anticipación inválidos", () => {
  assert.equal(validarPeticion({ token: "corto", categoria: "GRUPO 3", anticipaciones: [1] }).ok, false);
  assert.equal(validarPeticion({ token: TOKEN, categoria: "GRUPO 9", anticipaciones: [1] }).ok, false);
  assert.equal(validarPeticion({ token: TOKEN, categoria: "GRUPO 3", anticipaciones: [2] }).ok, false);
  assert.equal(validarPeticion({ token: TOKEN, categoria: "GRUPO 3", anticipaciones: [] }).ok, false);
  assert.equal(validarPeticion(null).ok, false);
});

test("manejarPush: 400 si es inválido, 200 si FCM acepta, sin registrar el token", async () => {
  const eventos = [];
  const deps = { gestionar: async () => true, registrar: (_e, ev, b) => eventos.push([ev, ...b]) };
  const mal = await manejarPush(new Request("https://x", { method: "POST", body: "{}" }), {}, true, deps);
  assert.equal(mal.status, 400);
  const bien = await manejarPush(new Request("https://x", { method: "POST",
    body: JSON.stringify({ token: TOKEN, categoria: "JUBILADOS", anticipaciones: [1] }) }), {}, true, deps);
  assert.equal(bien.status, 200);
  assert.deepEqual(eventos, [["push_alta", "jubilados", "d1", ""]]);
  assert.ok(!JSON.stringify(eventos).includes(TOKEN));
});

test("FCM: firma JWT, envía al tema correcto y suscribe con IID", async () => {
  _resetCache();
  const { privateKey } = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign"]);
  const pk = Buffer.from(await crypto.subtle.exportKey("pkcs8", privateKey)).toString("base64");
  const env = { FCM_SA: JSON.stringify({ project_id: "cuando-pagan", client_email: "x@y.iam.gserviceaccount.com",
    private_key: `-----BEGIN PRIVATE KEY-----\n${pk}\n-----END PRIVATE KEY-----\n` }) };
  const llamadas = [];
  const fetchFn = async (url, init) => {
    llamadas.push({ url, body: init.body });
    if (url.includes("oauth2")) return new Response(JSON.stringify({ access_token: "tok", expires_in: 3600 }));
    return new Response("{}", { status: 200 });
  };
  assert.equal(await enviarATema(env, { tema: "grupo3-d1", titulo: "T", cuerpo: "C" }, fetchFn), true);
  assert.equal(await gestionarTemas(env, TOKEN, ["grupo3-d1"], true, fetchFn), true);
  const send = llamadas.find((l) => l.url.includes("messages:send"));
  assert.match(send.url, /projects\/cuando-pagan\/messages:send/);
  assert.equal(JSON.parse(send.body).message.topic, "grupo3-d1");
  assert.ok(llamadas.some((l) => l.url.endsWith("iid/v1:batchAdd")));
  assert.equal(llamadas.filter((l) => l.url.includes("oauth2")).length, 1, "el token OAuth se reutiliza");
});
