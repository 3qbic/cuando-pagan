// Qué notificación sale hoy a cada tema de FCM. Función PURA (sin red ni reloj):
// el cron le pasa "hoy" en America/Panama y los datos empaquetados.
// Temas: {slug-categoria}-d{N}, N = días de anticipación (0, 1, 3).

export const ANTICIPACIONES = [0, 1, 3];

export const CATEGORIAS = {
  "JUBILADOS": { slug: "jubilados", nombre: "Jubilados" },
  "GASTOS DE REPRESENTACION": { slug: "gastosrep", nombre: "Gastos de representación" },
  "GRUPO 1": { slug: "grupo1", nombre: "Grupo 1" },
  "GRUPO 2": { slug: "grupo2", nombre: "Grupo 2" },
  "GRUPO 3": { slug: "grupo3", nombre: "Grupo 3" },
};

export const TEMAS_VALIDOS = new Set(
  Object.values(CATEGORIAS).flatMap((c) => ANTICIPACIONES.map((n) => `${c.slug}-d${n}`)),
);

/** "hoy" en Panamá (UTC-5 fijo, sin DST) como YYYY-MM-DD. */
export function hoyPanama(ahora = new Date()) {
  return new Date(ahora.getTime() - 5 * 3600 * 1000).toISOString().slice(0, 10);
}

/** Suma días a una fecha YYYY-MM-DD (aritmética en UTC, sin horas). */
export function sumarDias(iso, n) {
  const d = new Date(iso + "T00:00:00Z");
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

const DIAS = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
const MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
  "septiembre", "octubre", "noviembre", "diciembre"];

/** "jueves 30 de octubre" (sin depender de Intl). */
export function fechaLarga(iso) {
  const d = new Date(iso + "T00:00:00Z");
  return `${DIAS[d.getUTCDay()]} ${d.getUTCDate()} de ${MESES[d.getUTCMonth()]}`;
}

function semestreDe(iso) {
  const [a, m] = iso.split("-").map(Number);
  return `${a}-S${m <= 6 ? 1 : 2}`;
}

function titulo(n, quincena, decimo) {
  if (quincena && decimo) {
    return n === 0 ? "Hoy te pagan la quincena y se espera tu décimo 💸"
      : n === 1 ? "Mañana te pagan la quincena y se espera tu décimo 💸"
      : `Faltan ${n} días para tu pago y tu décimo`;
  }
  if (decimo) {
    return n === 0 ? "Hoy se espera tu décimo 💰"
      : n === 1 ? "Se espera tu décimo mañana 💰"
      : `Faltan ${n} días para tu décimo`;
  }
  return n === 0 ? "Hoy te pagan 💸" : n === 1 ? "Mañana te pagan 💸" : `Faltan ${n} días para tu pago`;
}

/**
 * @param {string} hoy YYYY-MM-DD en Panamá
 * @param {Array<{categoria:string, fecha_pago:string}>} calendario
 * @param {Array<{fecha_aprox:string}>} xiii
 * @param {string[]} semestres los de manifest.semestres (ej. "2026-S2")
 * @returns {Array<{tema:string, titulo:string, cuerpo:string}>} un aviso por tema, sin duplicados
 */
export function avisosDelDia(hoy, calendario, xiii, semestres) {
  // Si el semestre en curso no está publicado, no se avisa nada (grupos pueden cambiar).
  if (!semestres.includes(semestreDe(hoy))) return [];
  const out = [];
  for (const n of ANTICIPACIONES) {
    const objetivo = sumarDias(hoy, n);
    const hayDecimo = xiii.some((x) => x.fecha_aprox === objetivo);
    for (const [wire, cat] of Object.entries(CATEGORIAS)) {
      const hayQuincena = calendario.some((e) => e.categoria === wire && e.fecha_pago === objetivo);
      if (!hayQuincena && !hayDecimo) continue;
      const nota = hayDecimo && !hayQuincena ? "fecha aproximada (fuente: MEF)" : "fecha referencial (fuente: MEF)";
      out.push({
        tema: `${cat.slug}-d${n}`,
        titulo: titulo(n, hayQuincena, hayDecimo),
        cuerpo: `${cat.nombre} · ${fechaLarga(objetivo)} · ${nota}`,
      });
    }
  }
  return out;
}
