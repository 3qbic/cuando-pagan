// Metricas agregadas y anonimas con Workers Analytics Engine (binding USO,
// dataset cuandopagan_uso). NUNCA se registra IP, user-agent, token, ID ni la URL.
//
// Esquema de data points (index1 = blob1 = evento):
//
// | evento     | blob2      | blob3        | blob4           | double1      |
// |------------|------------|--------------|-----------------|--------------|
// | apertura   | plataforma | version app  | push ('1'/'0')  | data_version |
// | push_alta  | (fase 3) categoria | anticipacion | -       | -            |
//
// plataforma: web|android|ios|otro|desconocido. version: x.y.z|otro|desconocido.

const PLATAFORMAS = new Set(["web", "android", "ios"]);
const RE_VERSION = /^\d{1,3}\.\d{1,3}\.\d{1,3}$/;

export function dimensionesApertura(url) {
  const q = url.searchParams;
  const p = q.get("p");
  const v = q.get("v");
  const d = q.get("d");
  const dNum = d !== null && /^\d{1,4}$/.test(d) ? Number(d) : 0;
  return {
    plataforma: p === null ? "desconocido" : PLATAFORMAS.has(p) ? p : "otro",
    version: v === null ? "desconocido" : RE_VERSION.test(v) ? v : "otro",
    push: q.get("push") === "1" ? "1" : "0",
    dataVersion: dNum,
  };
}

// Generico: la metrica jamas debe romper la respuesta.
export function registrar(env, evento, blobs = [], doubles = []) {
  try {
    if (!env || !env.USO) return;
    env.USO.writeDataPoint({ indexes: [evento], blobs: [evento, ...blobs], doubles });
  } catch (_) {
    // se ignora a proposito
  }
}
