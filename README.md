# ¿Cuándo Pagan?

**App independiente y NO oficial** para consultar de un vistazo **cuándo le pagan al sector público de Panamá**, según el calendario que el Ministerio de Economía y Finanzas (MEF) publica en sus canales oficiales.

🔗 **En vivo (web):** https://cuandopagan.3qbic.com · 🔒 **Privacidad:** https://cuandopagan.3qbic.com/privacidad/

> [!IMPORTANT]
> **Esta app NO es oficial.** No representa al Gobierno de Panamá ni al MEF, y no está
> afiliada, patrocinada ni avalada por ninguna entidad del Estado. El MEF se cita únicamente
> como **fuente pública** de la información. Las fechas son **referenciales**; ante cualquier
> diferencia, prevalece la publicación oficial del MEF. La app no tramita ni resuelve pagos.

Proyecto **de código abierto** (Licencia MIT), hecho por [**3qbic**](https://3qbic.com). Sin cuentas ni datos personales; sin rastreadores publicitarios ni perfiles. La versión web usa analítica agregada y sin cookies (Cloudflare Web Analytics); la app móvil, ninguna. Lo tuyo se queda en tu dispositivo.

---

## Qué es este repo

Es **dual**:

1. **La app Flutter «¿Cuándo Pagan?»** (`lib/`, `android/`, `ios/`, `web/`) — Android / iOS / Web.
2. **El pipeline de datos + el "API"** (`pipeline/`, `worker/`) — no hay backend tradicional: el
   "API" son archivos JSON estáticos que sirve un Cloudflare Worker.

> **Documentos maestros:** [`ARQUITECTURA.md`](ARQUITECTURA.md) (sistema completo) ·
> [`README_calendario.md`](README_calendario.md) (modelo de datos y consultas SQL) ·
> [`CLAUDE.md`](CLAUDE.md) (resumen operativo).

## Estado

| Componente | Estado |
|------------|--------|
| App Flutter (onboarding, Home, Calendario, Décimo, Acerca) | ✅ **v0.1.1 en vivo** (web) — offline-first |
| Sitio + política de privacidad | ✅ Desplegado en `cuandopagan.3qbic.com` |
| Datos 2026 tabulados (CSV + DuckDB + JSON) | ✅ 120 filas (2 semestres) |
| Scraper del MEF (Python) | ✅ Detecta 2019–2026 |
| API: Cloudflare Worker (`/v1/*`) | 🚧 Probado local — **falta `wrangler deploy`** |
| Publicación en Google Play / App Store | ⏳ Próximamente |

La app hoy carga **100% offline** desde una semilla empaquetada (`assets/seed/all.json`), así que
funciona aunque el Worker aún no esté desplegado.

## La app (Flutter)

Arquitectura **clean, feature-first**: `lib/domain/` es Dart puro (entidades + lógica testeable
headless: `calcularProximoPago`, contador, detección de fechas modificadas, búsqueda);
`lib/data/` implementa contra el Worker (ETag/304) + drift (SQLite) + mappers; `lib/application/`
orquesta con Riverpod. Toda la lógica sensible (off-by-one de fechas, zona `America/Panamá` fija)
se prueba sin levantar la app.

```bash
flutter pub get
flutter test                               # suite completa (headless)
flutter run -d chrome                       # o -d <device>
dart run tool/check_forbidden_deps.dart     # falla si entra una dep de tracking/analytics
flutter build web --release                 # build de producción
```

**Invariantes no negociables:** cero SDKs de tracking/analytics/ads (hay check de CI); todo
"hoy"/contador usa `America/Panamá` fijo (UTC-5, sin DST); `fecha_pago` verbatim; disclaimer
"no oficial" omnipresente.

## El pipeline de datos + el "API"

```bash
# Regenerar todos los datos (CSV + DuckDB + JSON + datos del Worker)
python pipeline/build_dataset.py            # valida 60 filas/semestre; aborta si no cuadra

# ¿El MEF publicó un semestre nuevo?
python pipeline/scraper_mef.py              # exit code 10 si hay pendientes
python pipeline/scraper_mef.py --download   # baja los PDF nuevos

# Worker (el "API")
cd worker && npm install
npx wrangler dev                            # local
npx wrangler deploy                         # publica
```

**`pipeline/build_dataset.py` es el SOURCE OF TRUTH de los datos** (transcritos a mano del PDF del
MEF, cuyo layout es feo). Todo lo demás — CSV, DuckDB, los JSON en `data/` y en `worker/src/data/`,
y la semilla `assets/seed/all.json` — es **generado**; nunca editar a mano.

Endpoints del Worker: `/v1/version`, `/v1/all`, `/v1/calendario`, `/v1/grupos`, `/v1/xiii`,
`/v1/status`.

## Hechos clave del modelo de datos

- Categorías: `JUBILADOS`, `GASTOS DE REPRESENTACION`, `GRUPO 1`, `GRUPO 2`, `GRUPO 3`.
- **MIDES (Min. de Desarrollo Social) = GRUPO 3.**
- Cada semestre = **60 filas** (6 meses × 5 categorías × 2 quincenas); el generador lo valida.
- La leyenda Grupo→Entidad es casi idéntica entre semestres.
- Fuente MEF: https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/
- Infra a costo **$0** (Cloudflare free tier).

## Requisitos

- Flutter (Dart ≥ 3.4) para la app.
- Python 3.x con `requests` y `duckdb` para el pipeline.
- Node 18+ / npm y una cuenta Cloudflare (free) para el Worker.

## Licencia

[MIT](LICENSE) © 2026 3qbic — Alexis García. Las fechas provienen de publicaciones **públicas**
del MEF; esta app no está afiliada al MEF.
