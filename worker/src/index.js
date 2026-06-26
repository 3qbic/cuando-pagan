// Cloudflare Worker - API del Calendario de Pago del Sector Publico de Panama.
// Sirve JSON estatico (empaquetado en el deploy) con CORS, cache de borde y ETag/304.
// Free tier: 100k req/dia, 10ms CPU. Servir un JSON es <1ms -> sobra.
//
// Los datos se generan con pipeline/build_dataset.py, que los copia a worker/src/data/.
// Para publicar datos nuevos: correr build_dataset.py y luego `npm run deploy`.

import manifest from "./data/manifest.json";
import calendario from "./data/calendario.json";
import grupos from "./data/grupos_entidades.json";
import xiii from "./data/xiii_mes.json";
import { fetchMefSemesters, keyNum, MEF_URL } from "./mef.js";

const VERSION_TAG = `"v${manifest.data_version}"`; // ETag basado en data_version

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, If-None-Match",
};

function json(obj, { cacheSeconds = 3600, etag = VERSION_TAG, status = 200 } = {}) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": `public, max-age=${cacheSeconds}`,
      ETag: etag,
      ...CORS,
    },
  });
}

// La app llama esto al abrir: ~pocos bytes. Si no cambio nada, no baja el dataset.
const versionPayload = {
  data_version: manifest.data_version,
  fecha_publicacion: manifest.fecha_publicacion,
  semestres: manifest.semestres,
  total_filas: manifest.total_filas,
};

// Respuesta unica para que la app haga UN solo request y traiga todo.
const allPayload = {
  manifest,
  calendario,
  grupos_entidades: grupos,
  xiii_mes: xiii,
};

// --- Verificacion contra el MEF ---
// "Contabilizado" = lo que ya esta desplegado. Marcamos NUEVO solo lo cronologicamente
// posterior al ultimo semestre contabilizado (evita falsos positivos con los historicos).
const ACCOUNTED = manifest.semestres;
const LATEST_ACCOUNTED = Math.max(...ACCOUNTED.map(keyNum));

async function buildStatus() {
  const found = await fetchMefSemesters();
  const nuevos = found.filter((f) => keyNum(f.clave) > LATEST_ACCOUNTED).map((f) => f.clave);
  return {
    checked_at: new Date().toISOString(),
    fuente: MEF_URL,
    deployed_version: manifest.data_version,
    contabilizado: ACCOUNTED,
    publicado_en_mef: found.map((f) => f.clave),
    nuevos,
    hay_nuevo: nuevos.length > 0,
  };
}

export default {
  // Cron Trigger (ver wrangler.toml). Revisa el MEF y, si hay KV, guarda el resultado.
  async scheduled(event, env, ctx) {
    const status = await buildStatus();
    if (env && env.MEF_KV) {
      await env.MEF_KV.put("status", JSON.stringify(status));
    }
    // (sin KV el cron corre igual pero no persiste; /v1/status hara check en vivo)
  },

  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (request.method !== "GET") {
      return new Response("Method Not Allowed", { status: 405, headers: CORS });
    }

    const path = new URL(request.url).pathname.replace(/\/+$/, "") || "/";

    // 304 solo para endpoints de datos (no para /v1/status, que cambia aparte)
    if (path !== "/v1/status" && request.headers.get("If-None-Match") === VERSION_TAG) {
      return new Response(null, { status: 304, headers: { ETag: VERSION_TAG, ...CORS } });
    }

    switch (path) {
      case "/":
        return json({
          servicio: "Calendario de Pago del Sector Publico - Panama",
          fuente: manifest.fuente,
          data_version: manifest.data_version,
          endpoints: ["/v1/version", "/v1/manifest", "/v1/all",
                      "/v1/calendario", "/v1/grupos", "/v1/xiii", "/v1/status"],
        }, { cacheSeconds: 300 });
      case "/v1/version":
        return json(versionPayload, { cacheSeconds: 300 }); // cache corto: detecta cambios rapido
      case "/v1/manifest":
        return json(manifest);
      case "/v1/all":
        return json(allPayload);
      case "/v1/calendario":
        return json(calendario);
      case "/v1/grupos":
        return json(grupos);
      case "/v1/xiii":
        return json(xiii);
      case "/v1/status": {
        // ?live=1 fuerza un chequeo en vivo; si no, sirve el ultimo del cron (KV)
        const live = new URL(request.url).searchParams.get("live") === "1";
        if (!live && env && env.MEF_KV) {
          const cached = await env.MEF_KV.get("status");
          if (cached) {
            return json({ ...JSON.parse(cached), origen: "cron/kv" },
                        { cacheSeconds: 300, etag: '"status"' });
          }
        }
        try {
          return json({ ...(await buildStatus()), origen: "en-vivo" },
                      { cacheSeconds: 300, etag: '"status"' });
        } catch (e) {
          return json({ error: "no se pudo consultar el MEF", detalle: String(e) },
                      { cacheSeconds: 60, status: 502, etag: '"status"' });
        }
      }
      default:
        return json({ error: "not found", path }, { cacheSeconds: 60, status: 404 });
    }
  },
};
