# -*- coding: utf-8 -*-
"""
build_dataset.py  -- SOURCE OF TRUTH de los datos del calendario de pago.

Contiene los datos transcritos de los PDF (por semestre) y genera:
  - CSV (carpeta raiz):   calendario_pago_salarios_2026.csv, grupos_entidades.csv, xiii_mes_2026.csv
  - JSON publicado (data/): calendario.json, grupos_entidades.json, xiii_mes.json, manifest.json

El manifest.json es lo que la app movil consulta al abrir para saber si hay datos mas frescos.
Cuando se procese un nuevo semestre (ej. 2027-S1):
  1. Agregar su bloque a DATOS y, si aplica, a XIII.
  2. Subir DATA_VERSION en 1 y agregar la clave a SEMESTRES.
  3. Correr: python build_dataset.py   -> regenera CSV + JSON + manifest.
  4. Publicar la carpeta data/ (GitHub Pages / Supabase Storage / hosting estatico).
  5. Agregar la clave a pipeline/processed.json para que el scraper deje de marcarla.
"""
import csv, os, json, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "data")
WORKER_DATA = os.path.join(ROOT, "worker", "src", "data")  # copia que empaqueta el Worker

# ---- Versionado para la app ----
DATA_VERSION = 1                      # subir en +1 cada vez que cambien los datos
FECHA_PUBLICACION = "2026-06-26"      # fecha de esta generacion (manual)
SEMESTRES = ["2026-S1", "2026-S2"]    # semestres incluidos en este dataset

MESES = {"ene":1,"feb":2,"mar":3,"abr":4,"may":5,"jun":6,
         "jul":7,"ago":8,"sep":9,"oct":10,"nov":11,"dic":12}
MES_NUM = {"ENERO":1,"FEBRERO":2,"MARZO":3,"ABRIL":4,"MAYO":5,"JUNIO":6,
           "JULIO":7,"AGOSTO":8,"SEPTIEMBRE":9,"OCTUBRE":10,"NOVIEMBRE":11,"DICIEMBRE":12}
CATS = ["JUBILADOS", "GASTOS DE REPRESENTACION", "GRUPO 1", "GRUPO 2", "GRUPO 3"]

def iso(s):
    if not s: return ""
    d, m, y = s.split("-")
    return datetime.date(int(y), MESES[m], int(d)).isoformat()

# DATOS[anio][semestre][MES] = { categoria: ([q1: ini,cie,ret,pago],[q2: ...]) }
DATOS = {2026: {
 1: {
  "ENERO": {
   "JUBILADOS":(["22-dic-2025","23-dic-2025","29-dic-2025","02-ene-2026"],["07-ene-2026","08-ene-2026","13-ene-2026","16-ene-2026"]),
   "GASTOS DE REPRESENTACION":(["22-dic-2025","23-dic-2025","29-dic-2025","02-ene-2026"],["07-ene-2026","08-ene-2026","13-ene-2026","16-ene-2026"]),
   "GRUPO 1":(["22-dic-2025","26-dic-2025","06-ene-2026","12-ene-2026"],["07-ene-2026","12-ene-2026","22-ene-2026","27-ene-2026"]),
   "GRUPO 2":(["22-dic-2025","26-dic-2025","07-ene-2026","13-ene-2026"],["07-ene-2026","12-ene-2026","23-ene-2026","28-ene-2026"]),
   "GRUPO 3":(["22-dic-2025","26-dic-2025","08-ene-2026","14-ene-2026"],["07-ene-2026","12-ene-2026","26-ene-2026","29-ene-2026"]),
  },
  "FEBRERO": {
   "JUBILADOS":(["20-ene-2026","22-ene-2026","28-ene-2026","02-feb-2026"],["03-feb-2026","04-feb-2026","11-feb-2026","18-feb-2026"]),
   "GASTOS DE REPRESENTACION":(["20-ene-2026","22-ene-2026","28-ene-2026","02-feb-2026"],["03-feb-2026","04-feb-2026","11-feb-2026","18-feb-2026"]),
   "GRUPO 1":(["20-ene-2026","26-ene-2026","06-feb-2026","11-feb-2026"],["03-feb-2026","10-feb-2026","20-feb-2026","25-feb-2026"]),
   "GRUPO 2":(["20-ene-2026","26-ene-2026","09-feb-2026","12-feb-2026"],["03-feb-2026","10-feb-2026","23-feb-2026","26-feb-2026"]),
   "GRUPO 3":(["20-ene-2026","26-ene-2026","10-feb-2026","13-feb-2026"],["03-feb-2026","10-feb-2026","24-feb-2026","27-feb-2026"]),
  },
  "MARZO": {
   "JUBILADOS":(["20-feb-2026","23-feb-2026","27-feb-2026","04-mar-2026"],["03-mar-2026","05-mar-2026","16-mar-2026","19-mar-2026"]),
   "GASTOS DE REPRESENTACION":(["20-feb-2026","23-feb-2026","27-feb-2026","04-mar-2026"],["03-mar-2026","05-mar-2026","16-mar-2026","19-mar-2026"]),
   "GRUPO 1":(["20-feb-2026","24-feb-2026","06-mar-2026","11-mar-2026"],["03-mar-2026","06-mar-2026","23-mar-2026","26-mar-2026"]),
   "GRUPO 2":(["20-feb-2026","24-feb-2026","09-mar-2026","12-mar-2026"],["03-mar-2026","06-mar-2026","24-mar-2026","27-mar-2026"]),
   "GRUPO 3":(["20-feb-2026","24-feb-2026","10-mar-2026","13-mar-2026"],["03-mar-2026","06-mar-2026","25-mar-2026","30-mar-2026"]),
  },
  "ABRIL": {
   "JUBILADOS":(["17-mar-2026","19-mar-2026","27-mar-2026","01-abr-2026"],["02-abr-2026","07-abr-2026","13-abr-2026","16-abr-2026"]),
   "GASTOS DE REPRESENTACION":(["17-mar-2026","19-mar-2026","27-mar-2026","01-abr-2026"],["02-abr-2026","07-abr-2026","13-abr-2026","16-abr-2026"]),
   "GRUPO 1":(["17-mar-2026","25-mar-2026","08-abr-2026","13-abr-2026"],["02-abr-2026","08-abr-2026","22-abr-2026","27-abr-2026"]),
   "GRUPO 2":(["17-mar-2026","25-mar-2026","09-abr-2026","14-abr-2026"],["02-abr-2026","08-abr-2026","23-abr-2026","28-abr-2026"]),
   "GRUPO 3":(["17-mar-2026","25-mar-2026","10-abr-2026","15-abr-2026"],["02-abr-2026","08-abr-2026","24-abr-2026","29-abr-2026"]),
  },
  "MAYO": {
   "JUBILADOS":(["17-abr-2026","21-abr-2026","28-abr-2026","04-may-2026"],["05-may-2026","07-may-2026","14-may-2026","19-may-2026"]),
   "GASTOS DE REPRESENTACION":(["17-abr-2026","21-abr-2026","28-abr-2026","04-may-2026"],["05-may-2026","07-may-2026","14-may-2026","19-may-2026"]),
   "GRUPO 1":(["17-abr-2026","23-abr-2026","07-may-2026","12-may-2026"],["05-may-2026","08-may-2026","22-may-2026","27-may-2026"]),
   "GRUPO 2":(["17-abr-2026","23-abr-2026","08-may-2026","13-may-2026"],["05-may-2026","08-may-2026","25-may-2026","28-may-2026"]),
   "GRUPO 3":(["17-abr-2026","23-abr-2026","11-may-2026","14-may-2026"],["05-may-2026","08-may-2026","26-may-2026","29-may-2026"]),
  },
  "JUNIO": {
   "JUBILADOS":(["19-may-2026","21-may-2026","29-may-2026","03-jun-2026"],["02-jun-2026","04-jun-2026","15-jun-2026","18-jun-2026"]),
   "GASTOS DE REPRESENTACION":(["19-may-2026","21-may-2026","29-may-2026","03-jun-2026"],["02-jun-2026","04-jun-2026","15-jun-2026","18-jun-2026"]),
   "GRUPO 1":(["19-may-2026","25-may-2026","08-jun-2026","11-jun-2026"],["02-jun-2026","08-jun-2026","22-jun-2026","25-jun-2026"]),
   "GRUPO 2":(["19-may-2026","25-may-2026","09-jun-2026","12-jun-2026"],["02-jun-2026","08-jun-2026","23-jun-2026","26-jun-2026"]),
   "GRUPO 3":(["19-may-2026","25-may-2026","10-jun-2026","15-jun-2026"],["02-jun-2026","08-jun-2026","24-jun-2026","29-jun-2026"]),
  },
 },
 2: {
  "JULIO": {
   "JUBILADOS":(["17-jun-2026","19-jun-2026","29-jun-2026","02-jul-2026"],["02-jul-2026","07-jul-2026","13-jul-2026","16-jul-2026"]),
   "GASTOS DE REPRESENTACION":(["17-jun-2026","19-jun-2026","29-jun-2026","02-jul-2026"],["02-jul-2026","07-jul-2026","13-jul-2026","16-jul-2026"]),
   "GRUPO 1":(["17-jun-2026","24-jun-2026","06-jul-2026","13-jul-2026"],["02-jul-2026","09-jul-2026","21-jul-2026","27-jul-2026"]),
   "GRUPO 2":(["17-jun-2026","24-jun-2026","07-jul-2026","14-jul-2026"],["02-jul-2026","09-jul-2026","22-jul-2026","28-jul-2026"]),
   "GRUPO 3":(["17-jun-2026","24-jun-2026","08-jul-2026","15-jul-2026"],["02-jul-2026","09-jul-2026","23-jul-2026","29-jul-2026"]),
  },
  "AGOSTO": {
   "JUBILADOS":(["17-jul-2026","21-jul-2026","29-jul-2026","03-ago-2026"],["04-ago-2026","06-ago-2026","12-ago-2026","17-ago-2026"]),
   "GASTOS DE REPRESENTACION":(["17-jul-2026","21-jul-2026","29-jul-2026","03-ago-2026"],["04-ago-2026","06-ago-2026","12-ago-2026","17-ago-2026"]),
   "GRUPO 1":(["17-jul-2026","24-jul-2026","06-ago-2026","12-ago-2026"],["04-ago-2026","10-ago-2026","20-ago-2026","26-ago-2026"]),
   "GRUPO 2":(["17-jul-2026","24-jul-2026","07-ago-2026","13-ago-2026"],["04-ago-2026","10-ago-2026","21-ago-2026","27-ago-2026"]),
   "GRUPO 3":(["17-jul-2026","24-jul-2026","10-ago-2026","14-ago-2026"],["04-ago-2026","10-ago-2026","24-ago-2026","28-ago-2026"]),
  },
  "SEPTIEMBRE": {
   "JUBILADOS":(["18-ago-2026","21-ago-2026","28-ago-2026","02-sep-2026"],["02-sep-2026","07-sep-2026","14-sep-2026","17-sep-2026"]),
   "GASTOS DE REPRESENTACION":(["18-ago-2026","21-ago-2026","28-ago-2026","02-sep-2026"],["02-sep-2026","07-sep-2026","14-sep-2026","17-sep-2026"]),
   "GRUPO 1":(["18-ago-2026","25-ago-2026","04-sep-2026","11-sep-2026"],["02-sep-2026","09-sep-2026","21-sep-2026","25-sep-2026"]),
   "GRUPO 2":(["18-ago-2026","25-ago-2026","07-sep-2026","14-sep-2026"],["02-sep-2026","09-sep-2026","22-sep-2026","28-sep-2026"]),
   "GRUPO 3":(["18-ago-2026","25-ago-2026","08-sep-2026","15-sep-2026"],["02-sep-2026","09-sep-2026","23-sep-2026","29-sep-2026"]),
  },
  "OCTUBRE": {
   "JUBILADOS":(["17-sep-2026","22-sep-2026","28-sep-2026","01-oct-2026"],["02-oct-2026","06-oct-2026","13-oct-2026","16-oct-2026"]),
   "GASTOS DE REPRESENTACION":(["17-sep-2026","22-sep-2026","28-sep-2026","01-oct-2026"],["02-oct-2026","06-oct-2026","13-oct-2026","16-oct-2026"]),
   "GRUPO 1":(["17-sep-2026","24-sep-2026","06-oct-2026","12-oct-2026"],["02-oct-2026","09-oct-2026","20-oct-2026","27-oct-2026"]),
   "GRUPO 2":(["17-sep-2026","24-sep-2026","07-oct-2026","13-oct-2026"],["02-oct-2026","09-oct-2026","21-oct-2026","28-oct-2026"]),
   "GRUPO 3":(["17-sep-2026","24-sep-2026","08-oct-2026","14-oct-2026"],["02-oct-2026","09-oct-2026","22-oct-2026","29-oct-2026"]),
  },
  "NOVIEMBRE": {
   "JUBILADOS":(["19-oct-2026","22-oct-2026","28-oct-2026","02-nov-2026"],["06-nov-2026","09-nov-2026","12-nov-2026","17-nov-2026"]),
   "GASTOS DE REPRESENTACION":(["19-oct-2026","22-oct-2026","28-oct-2026","02-nov-2026"],["06-nov-2026","09-nov-2026","12-nov-2026","17-nov-2026"]),
   "GRUPO 1":(["19-oct-2026","26-oct-2026","05-nov-2026","11-nov-2026"],["06-nov-2026","12-nov-2026","19-nov-2026","25-nov-2026"]),
   "GRUPO 2":(["19-oct-2026","26-oct-2026","06-nov-2026","12-nov-2026"],["06-nov-2026","12-nov-2026","20-nov-2026","26-nov-2026"]),
   "GRUPO 3":(["19-oct-2026","26-oct-2026","09-nov-2026","13-nov-2026"],["06-nov-2026","12-nov-2026","23-nov-2026","27-nov-2026"]),
  },
  "DICIEMBRE": {
   "JUBILADOS":(["19-nov-2026","23-nov-2026","27-nov-2026","02-dic-2026"],["02-dic-2026","07-dic-2026","14-dic-2026","17-dic-2026"]),
   "GASTOS DE REPRESENTACION":(["19-nov-2026","23-nov-2026","27-nov-2026","02-dic-2026"],["02-dic-2026","07-dic-2026","14-dic-2026","17-dic-2026"]),
   "GRUPO 1":(["19-nov-2026","24-nov-2026","04-dic-2026","11-dic-2026"],["02-dic-2026","09-dic-2026","18-dic-2026","28-dic-2026"]),
   "GRUPO 2":(["19-nov-2026","24-nov-2026","07-dic-2026","14-dic-2026"],["02-dic-2026","09-dic-2026","22-dic-2026","29-dic-2026"]),
   "GRUPO 3":(["19-nov-2026","24-nov-2026","09-dic-2026","15-dic-2026"],["02-dic-2026","09-dic-2026","23-dic-2026","30-dic-2026"]),
  },
 },
}}

# XIII MES APROX (anio, semestre, MES, fecha)
XIII = [
 (2026, 1, "FEBRERO",  "20-feb-2026"),
 (2026, 2, "AGOSTO",   "06-ago-2026"),
 (2026, 2, "DICIEMBRE","04-dic-2026"),
]

# Leyenda GRUPOS POR FECHA DE PAGO (identica en ambos semestres de 2026)
GRUPOS = {
 "GRUPO 1": ["Pensiones Alimenticias Grupo N.1","S.P.I.","Estamentos de Seguridad",
             "Min. de Educacion","Min. de Cultura"],
 "GRUPO 2": ["Pensiones Alimenticias Grupo N.2 y N.3","Asamblea Nacional","Contraloria General",
             "Min. de la Presidencia","Min. de Relaciones Exteriores","Min. de Comercio e Industrias",
             "Min. de Obras Publicas","Min. de Economia y Finanzas","Min. de Gobierno",
             "Min. de Seguridad Publica","Min. de Ambiente","Tribunal Advo. de la Funcion Publica",
             "Defensoria del Pueblo"],
 "GRUPO 3": ["Min. de Desarrollo Agropecuario","Min. de Salud","Min. de Trabajo y Desarrollo Laboral",
             "Min. de Vivienda","Min. de Desarrollo Social","Tribunal Administrativo Tributario",
             "Min. de la Mujer","Organo Judicial","Procuraduria General de la Nacion",
             "Procuraduria de la Administracion","Tribunal Electoral","Fiscalia General Electoral",
             "Otros Gastos de Admon.","Tribunal de Cuentas","Fiscalia de Cuentas"],
}

def construir_calendario():
    rows = []
    for anio in sorted(DATOS):
        for sem in sorted(DATOS[anio]):
            for mes, cats in DATOS[anio][sem].items():
                for cat in CATS:
                    for qi, q in enumerate(cats[cat], start=1):
                        rows.append({
                            "anio": anio, "semestre": sem, "mes": mes, "mes_num": MES_NUM[mes],
                            "categoria": cat, "quincena": qi,
                            "inicio_registro": iso(q[0]), "cierre_registro": iso(q[1]),
                            "retencion_ach": iso(q[2]), "fecha_pago": iso(q[3]),
                        })
    return rows

def validar(rows):
    """Cada semestre debe tener 60 filas (6 meses x 5 categorias x 2 quincenas)."""
    from collections import Counter
    c = Counter((r["anio"], r["semestre"]) for r in rows)
    errores = [f"{a}-S{s}: {n} filas (esperado 60)" for (a, s), n in c.items() if n != 60]
    if errores:
        raise SystemExit("VALIDACION FALLIDA:\n  " + "\n  ".join(errores))
    return c

def main():
    os.makedirs(DATA, exist_ok=True)
    os.makedirs(WORKER_DATA, exist_ok=True)
    rows = construir_calendario()
    conteo = validar(rows)

    grupos_rows = [{"grupo": g, "entidad": e} for g, ents in GRUPOS.items() for e in ents]
    xiii_rows = [{"anio": a, "semestre": s, "mes": m, "fecha_aprox": iso(f)} for a, s, m, f in XIII]

    # ----- CSV (raiz) -----
    def write_csv(name, fields, data):
        with open(os.path.join(ROOT, name), "w", newline="", encoding="utf-8-sig") as fh:
            w = csv.DictWriter(fh, fieldnames=fields); w.writeheader(); w.writerows(data)
    write_csv("calendario_pago_salarios_2026.csv",
              ["anio","semestre","mes","mes_num","categoria","quincena",
               "inicio_registro","cierre_registro","retencion_ach","fecha_pago"], rows)
    write_csv("grupos_entidades.csv", ["grupo","entidad"], grupos_rows)
    write_csv("xiii_mes_2026.csv", ["anio","semestre","mes","fecha_aprox"], xiii_rows)

    # ----- JSON publicado (data/ y worker/src/data/) -----
    def write_json(name, obj):
        for d in (DATA, WORKER_DATA):
            with open(os.path.join(d, name), "w", encoding="utf-8") as fh:
                json.dump(obj, fh, ensure_ascii=False, indent=2)
    write_json("calendario.json", rows)
    write_json("grupos_entidades.json", grupos_rows)
    write_json("xiii_mes.json", xiii_rows)

    manifest = {
        "data_version": DATA_VERSION,
        "fecha_publicacion": FECHA_PUBLICACION,
        "semestres": SEMESTRES,
        "fuente": MEF_FUENTE,
        "archivos": {
            "calendario": "calendario.json",
            "grupos_entidades": "grupos_entidades.json",
            "xiii_mes": "xiii_mes.json",
        },
        "conteo": {f"{a}-S{s}": n for (a, s), n in conteo.items()},
        "total_filas": len(rows),
    }
    write_json("manifest.json", manifest)

    print(f"OK  calendario: {len(rows)} filas | grupos: {len(grupos_rows)} | xiii: {len(xiii_rows)}")
    print(f"    data_version={DATA_VERSION}  semestres={SEMESTRES}")
    print(f"    CSV -> {ROOT}")
    print(f"    JSON+manifest -> {DATA}")
    print(f"    JSON para Worker -> {WORKER_DATA}")

MEF_FUENTE = "https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/"

if __name__ == "__main__":
    main()
