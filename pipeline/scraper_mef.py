# -*- coding: utf-8 -*-
"""
scraper_mef.py
Detecta y descarga los Calendarios de Registro y Pago de Salarios publicados por el MEF.

Que hace:
  1. Descarga el HTML de la pagina del MEF.
  2. Extrae todos los enlaces a PDF y su texto (ej. "I Semestre 2027").
  3. Identifica (anio, semestre) por el TEXTO del enlace (no por el nombre del archivo,
     que es inconsistente).
  4. Compara contra pipeline/processed.json (registro de semestres ya procesados).
  5. Reporta los semestres NUEVOS y, con --download, los baja a ./descargas/.

Sin dependencias externas mas alla de 'requests'.

Uso:
  python scraper_mef.py            # solo reporta que hay nuevo
  python scraper_mef.py --download # ademas descarga los PDF nuevos
  python scraper_mef.py --all      # ignora processed.json y lista TODO lo publicado
"""
import os, re, sys, json, html
import requests

MEF_URL = "https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROCESSED = os.path.join(BASE_DIR, "processed.json")
DOWNLOAD_DIR = os.path.join(BASE_DIR, "descargas")
HEADERS = {"User-Agent": "Mozilla/5.0 (calendario-pagos-pa scraper)"}

# Solo nos interesan calendarios de pago de SALARIOS (no otros PDF de la pagina)
ANCHOR_RE = re.compile(r'<a[^>]+href="([^"]+\.pdf)"[^>]*>(.*?)</a>', re.IGNORECASE | re.DOTALL)
# Encabezado que contiene solo un año (la pagina agrupa los PDF por año)
HEADING_YEAR_RE = re.compile(r'<h[1-6][^>]*>\s*(20\d{2})\s*</h[1-6]>', re.IGNORECASE)
# Combinado, en orden de documento: o un encabezado-año o un anchor a PDF
TOKEN_RE = re.compile(
    r'(?P<head><h[1-6][^>]*>\s*(?P<year>20\d{2})\s*</h[1-6]>)'
    r'|(?P<anchor><a[^>]+href="(?P<url>[^"]+\.pdf)"[^>]*>(?P<text>.*?)</a>)',
    re.IGNORECASE | re.DOTALL)
YEAR_RE = re.compile(r'(20\d{2})')

def strip_tags(s):
    return html.unescape(re.sub(r'<[^>]+>', '', s)).strip()

def parse_semestre(texto):
    """Devuelve 1, 2 o None segun el texto del enlace."""
    t = texto.lower()
    if re.search(r'\b(ii|2do|2da|segundo|segunda)\b', t):
        return 2
    if re.search(r'\b(i|1er|1ra|1ro|primer|primera)\b', t):
        return 1
    return None

def year_from(texto, url):
    """Año confiable: 1) en el texto del enlace, 2) en el NOMBRE del archivo
    (no en la carpeta /uploads/AAAA/MM/ que es la fecha de subida)."""
    m = YEAR_RE.search(texto)
    if m:
        return int(m.group(1))
    basename = url.rsplit("/", 1)[-1]      # descarta la ruta de subida
    m = YEAR_RE.search(basename)
    if m:
        return int(m.group(1))
    return None

def fetch_links():
    r = requests.get(MEF_URL, headers=HEADERS, timeout=30)
    r.raise_for_status()
    encontrados = {}
    current_year = None
    # Recorremos el documento en orden: cada anchor hereda el ultimo año-encabezado.
    for tok in TOKEN_RE.finditer(r.text):
        if tok.group("head"):
            current_year = int(tok.group("year"))
            continue
        texto = strip_tags(tok.group("text"))
        url = tok.group("url")
        if 'semestre' not in texto.lower():
            continue
        sem = parse_semestre(texto)
        if not sem:
            continue
        # Prioridad de año: encabezado de seccion > texto/archivo
        anio = current_year or year_from(texto, url)
        if not anio:
            continue
        clave = f"{anio}-S{sem}"
        encontrados.setdefault(clave, {"anio": anio, "semestre": sem,
                                       "texto": texto, "url": url})
    return encontrados

def load_processed():
    if os.path.exists(PROCESSED):
        with open(PROCESSED, encoding="utf-8") as f:
            return json.load(f)
    return {"procesados": []}

def main():
    args = set(sys.argv[1:])
    publicados = fetch_links()
    proc = load_processed()
    ya = set(proc.get("procesados", []))

    print(f"Publicados en el MEF: {len(publicados)} semestres")
    for clave in sorted(publicados):
        flag = "  " if (clave in ya and "--all" not in args) else "NUEVO"
        print(f"  [{flag}] {clave}  -> {publicados[clave]['texto']}")

    nuevos = {k: v for k, v in publicados.items()
              if "--all" in args or k not in ya}
    pendientes = {k: v for k, v in publicados.items() if k not in ya}

    print()
    if not pendientes:
        print("No hay semestres nuevos por procesar.")
    else:
        print(f"Semestres NUEVOS (no en processed.json): {', '.join(sorted(pendientes))}")

    if "--download" in args and (pendientes or "--all" in args):
        os.makedirs(DOWNLOAD_DIR, exist_ok=True)
        objetivo = nuevos if "--all" in args else pendientes
        for clave, info in sorted(objetivo.items()):
            dest = os.path.join(DOWNLOAD_DIR, f"calendario_{clave}.pdf")
            print(f"  Descargando {clave} ...", end=" ")
            try:
                pdf = requests.get(info["url"], headers=HEADERS, timeout=60)
                pdf.raise_for_status()
                with open(dest, "wb") as f:
                    f.write(pdf.content)
                print(f"OK ({len(pdf.content)//1024} KB) -> {dest}")
            except Exception as e:
                print("ERROR", e)
        print("\nSiguiente paso: extraer la tabla de cada PDF y validar 60 filos por semestre")
        print("(6 meses x 5 categorias x 2 quincenas) antes de publicar. Ver ARQUITECTURA.md.")

    # exit code 10 si hay pendientes (util para CI / cron)
    sys.exit(10 if pendientes else 0)

if __name__ == "__main__":
    main()
