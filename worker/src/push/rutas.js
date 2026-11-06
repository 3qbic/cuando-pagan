// POST /v1/push/alta y /v1/push/baja. Valida y suscribe/desuscribe el token
// a los temas {categoria}-d{N}. El token NO se guarda ni se registra.
import { ANTICIPACIONES, CATEGORIAS } from "./avisos.js";

const TOKEN_RE = /^[A-Za-z0-9_:\-]{100,4096}$/;

/** @returns {{ok:true, token:string, temas:string[]} | {ok:false, error:string}} */
export function validarPeticion(body) {
  if (!body || typeof body !== "object") return { ok: false, error: "cuerpo inválido" };
  const { token, categoria, anticipaciones } = body;
  if (typeof token !== "string" || !TOKEN_RE.test(token)) return { ok: false, error: "token inválido" };
  const cat = CATEGORIAS[categoria];
  if (!cat) return { ok: false, error: "categoría inválida" };
  if (!Array.isArray(anticipaciones) || anticipaciones.length === 0 || anticipaciones.length > 3) {
    return { ok: false, error: "anticipaciones inválidas" };
  }
  const ns = [...new Set(anticipaciones)];
  if (!ns.every((n) => ANTICIPACIONES.includes(n))) return { ok: false, error: "anticipación no permitida" };
  return { ok: true, token, temas: ns.map((n) => `${cat.slug}-d${n}`), categoria: cat.slug, anticipaciones: ns };
}

export async function manejarPush(request, env, alta, { gestionar, registrar }) {
  let body;
  try { body = await request.json(); } catch { body = null; }
  const v = validarPeticion(body);
  if (!v.ok) return { status: 400, cuerpo: { error: v.error } };
  try {
    const ok = await gestionar(env, v.token, v.temas, alta);
    if (!ok) return { status: 502, cuerpo: { error: "FCM rechazó la operación" } };
  } catch {
    return { status: 502, cuerpo: { error: "no se pudo contactar a FCM" } };
  }
  for (const n of v.anticipaciones) registrar(env, alta ? "push_alta" : "push_baja", [v.categoria, `d${n}`, ""], [1]);
  return { status: 200, cuerpo: { ok: true, temas: v.temas } };
}
