# Calendario de Pago del Sector Público de Panamá

Datos tabulados, API serverless y (próximamente) app móvil para responder una sola pregunta:
**¿cuándo le pagan a tal institución?** La fuente son los PDF semestrales que publica el
Ministerio de Economía y Finanzas (MEF) / Contraloría General de la República.

> **Documento maestro:** [`ARQUITECTURA.md`](ARQUITECTURA.md). Léelo para entender todo el sistema.
> Este README es el punto de entrada y la guía para continuar en otra sesión.

---

## Qué hay hecho (estado a 2026-06-26)

| Componente | Estado |
|------------|--------|
| Datos 2026 tabulados (CSV + DuckDB + JSON) | Hecho — 120 filas |
| Scraper del MEF (Python) | Hecho y probado (detecta 2019–2026) |
| API: Cloudflare Worker (`/v1/*`) | Hecho y probado local — **falta `wrangler deploy`** |
| Verificación automática: Cron + `/v1/status` | Hecho y probado |
| App móvil (Flutter) | **Pendiente** — diseño definido en ARQUITECTURA §6 |
| Notificaciones push / auth (Supabase) | Fase 2, opcional |

## Hechos clave (para no releer todo)

- **MIDES (Min. de Desarrollo Social) = GRUPO 3.** La consulta núcleo está en ARQUITECTURA §3.4.
- Categorías: `JUBILADOS`, `GASTOS DE REPRESENTACION`, `GRUPO 1`, `GRUPO 2`, `GRUPO 3`.
- Cada semestre = 60 filas (6 meses × 5 categorías × 2 quincenas). El generador valida esto.
- La leyenda Grupo→Entidad es **idéntica entre semestres**; cambia muy rara vez.
- Fuente MEF: https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/
- Infra a costo **$0** (Cloudflare Workers free tier).

## Estructura

```
├─ ARQUITECTURA.md        <- documento maestro (LEER PRIMERO)
├─ README_calendario.md   <- guía rápida de los datos y consultas SQL
├─ *.pdf                  <- PDF fuente del MEF (1er y 2do semestre 2026)
├─ *.csv  *.duckdb        <- datos generados (consultables)
├─ data/                  <- JSON publicado (manifest + calendario + grupos + xiii)
├─ pipeline/              <- generación y scraping
│  ├─ build_dataset.py    <- SOURCE OF TRUTH de los datos + generador
│  ├─ scraper_mef.py      <- detecta/baja semestres nuevos del MEF
│  └─ processed.json      <- semestres ya procesados
└─ worker/                <- Cloudflare Worker (el "API")
   ├─ src/index.js        <- rutas /v1/*, CORS, ETag/304, cron scheduled
   ├─ src/mef.js          <- detección de semestres (port JS del scraper)
   └─ wrangler.toml       <- config + cron trigger + KV opcional
```

## Cómo correr cada cosa

```bash
# 1) Regenerar todos los datos (CSV + DuckDB + JSON + datos del Worker)
python pipeline/build_dataset.py

# 2) Ver si el MEF publicó un semestre nuevo
python pipeline/scraper_mef.py            # exit code 10 si hay pendientes
python pipeline/scraper_mef.py --download # baja los PDF nuevos a pipeline/descargas/

# 3) Desplegar / probar el Worker (API)
cd worker
npm install
npx wrangler dev        # local
npx wrangler login      # 1a vez
npx wrangler deploy     # publica -> https://calendario-pago-pa.<subdominio>.workers.dev
```

Endpoints del Worker: `/v1/version` (lo que la app consulta al abrir), `/v1/all` (todo en un
request), `/v1/calendario`, `/v1/grupos`, `/v1/xiii`, `/v1/status` (¿hay semestre nuevo en el MEF?).

## Próximos pasos (para retomar)

1. `wrangler deploy` del Worker con la cuenta Cloudflare → obtener la URL pública.
2. (Opcional) Activar KV para que el cron persista el `/v1/status`. Ver ARQUITECTURA §5.3.
3. **Construir la app Flutter**: pantalla de selección de institución + próximos pagos,
   consumiendo `/v1/all`, con SQLite local y semilla offline. Diseño en ARQUITECTURA §6.
4. Cuando el MEF publique 2027: seguir el **runbook anual** (ARQUITECTURA §8).

## Requisitos

- Python 3.x con `requests` y `duckdb` (`pip install requests duckdb`).
- Node 18+ y npm (para el Worker / wrangler).
- Cuenta de Cloudflare (free) para desplegar el Worker.

## Limitación honesta

La **extracción de la tabla del PDF** hoy es asistida (el layout del PDF es feo: celdas
combinadas, columnas pegadas). El scraper automatiza *detectar y descargar*; la transcripción a
`build_dataset.py` se valida con el chequeo de 60 filas/semestre antes de publicar. Automatizar el
parseo del PDF requeriría `pdfplumber`/`camelot` + validación. Ver ARQUITECTURA §4.3.
