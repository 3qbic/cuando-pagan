// Deteccion de semestres publicados por el MEF (port JS de pipeline/scraper_mef.py).
// Asigna el año por el ENCABEZADO de seccion de la pagina (no por la carpeta /uploads/AAAA/MM/,
// que es la fecha de subida y engaña: el 1er semestre se sube en diciembre del año anterior).

export const MEF_URL =
  "https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/";

// Token en orden de documento: o un encabezado-año o un anchor a PDF.
const TOKEN_RE =
  /<h[1-6][^>]*>\s*(20\d{2})\s*<\/h[1-6]>|<a[^>]+href="([^"]+\.pdf)"[^>]*>([\s\S]*?)<\/a>/gi;
const YEAR_RE = /(20\d{2})/;

function stripTags(s) {
  return s
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ").replace(/&#0?38;/g, "&")
    .trim();
}

function parseSemestre(texto) {
  const t = texto.toLowerCase();
  if (/\b(ii|2do|2da|segundo|segunda)\b/.test(t)) return 2;
  if (/\b(i|1er|1ra|1ro|primer|primera)\b/.test(t)) return 1;
  return null;
}

function yearFrom(texto, url) {
  let m = texto.match(YEAR_RE);
  if (m) return parseInt(m[1], 10);
  const basename = url.split("/").pop();           // descarta la ruta de subida
  m = basename.match(YEAR_RE);
  return m ? parseInt(m[1], 10) : null;
}

// Devuelve [{anio, semestre, clave, texto, url}] ordenado por clave.
export function parseSemesters(htmlText) {
  const encontrados = new Map();
  let currentYear = null;
  let tok;
  TOKEN_RE.lastIndex = 0;
  while ((tok = TOKEN_RE.exec(htmlText)) !== null) {
    if (tok[1]) { currentYear = parseInt(tok[1], 10); continue; } // encabezado-año
    const url = tok[2];
    const texto = stripTags(tok[3]);
    if (!/semestre/i.test(texto)) continue;
    const sem = parseSemestre(texto);
    if (!sem) continue;
    const anio = currentYear || yearFrom(texto, url);
    if (!anio) continue;
    const clave = `${anio}-S${sem}`;
    if (!encontrados.has(clave)) encontrados.set(clave, { anio, semestre: sem, clave, texto, url });
  }
  return [...encontrados.values()].sort((a, b) => a.clave.localeCompare(b.clave));
}

export async function fetchMefSemesters() {
  const r = await fetch(MEF_URL, {
    headers: { "User-Agent": "Mozilla/5.0 (calendario-pagos-pa worker)" },
    cf: { cacheTtl: 3600, cacheEverything: true }, // cachea en el borde 1h: no martilla al MEF
  });
  if (!r.ok) throw new Error("MEF HTTP " + r.status);
  return parseSemesters(await r.text());
}

// clave "2027-S1" -> 20271 (comparable cronologicamente)
export function keyNum(clave) {
  const [a, s] = clave.split("-S");
  return parseInt(a, 10) * 10 + parseInt(s, 10);
}
