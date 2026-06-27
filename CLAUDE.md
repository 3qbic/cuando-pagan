# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Qué es esto

Datos tabulados + "API" serverless para responder **"¿cuándo le pagan a tal institución del sector público de Panamá?"**. La fuente son los PDF semestrales del MEF / Contraloría (CGR). No hay backend tradicional: el "API" son archivos JSON estáticos servidos por un Cloudflare Worker. **El repo es dual:** (1) el pipeline de datos + Worker (Python/JS), y (2) la **app Flutter «¿Cuándo Pagan?»** (Android/iOS/Web) que consume ese Worker — su fundación (dominio + datos offline-first) ya está en `lib/`.

**Documentos maestros:** para el pipeline/Worker, lee `ARQUITECTURA.md` (+ `README_calendario.md` para el modelo de datos/SQL). Para la **app Flutter**, lee `docs/superpowers/specs/2026-06-26-app-cuando-pagan-design.md` (diseño; **§0.1 = correcciones vinculantes que prevalecen sobre el cuerpo**) y `docs/superpowers/plans/` (planes de implementación). Este archivo solo resume lo operativo.

## Comandos

```bash
# Regenerar TODOS los datos (CSV raíz + data/*.json + worker/src/data/*.json + manifest)
python pipeline/build_dataset.py        # valida 60 filas/semestre; aborta si no cuadra

# ¿El MEF publicó un semestre nuevo?
python pipeline/scraper_mef.py          # reporta; exit code 10 si hay pendientes
python pipeline/scraper_mef.py --download   # baja los PDF nuevos a pipeline/descargas/
python pipeline/scraper_mef.py --all        # lista TODO lo publicado (2019–2026)

# Worker (el "API")
cd worker
npm install
npx wrangler dev        # local
npx wrangler login      # primera vez
npx wrangler deploy     # publica -> https://calendario-pago-pa.<subdominio>.workers.dev
```

Requisitos: Python 3.x con `requests` y `duckdb`; Node 18+ / npm; cuenta Cloudflare (free) para desplegar.

No hay suite de tests automatizada. La "prueba" del pipeline es la validación de 60 filas/semestre dentro de `build_dataset.py`.

## Arquitectura — lo no obvio

**`pipeline/build_dataset.py` es el SOURCE OF TRUTH de los datos.** Los datos del calendario están transcritos a mano dentro del dict `DATOS` de ese archivo (no se parsean del PDF automáticamente — el layout del PDF es feo). Todo lo demás (CSV, DuckDB, los JSON en `data/` y en `worker/src/data/`) es **generado**; nunca editar esos archivos a mano, editar `build_dataset.py` y regenerar.

**Flujo de datos:** PDF del MEF → transcripción manual a `DATOS` en `build_dataset.py` → `python build_dataset.py` genera CSV + JSON en dos destinos: `data/` (copia de referencia) y `worker/src/data/` (lo que el Worker empaqueta en el bundle vía import).

**El Worker (`worker/src/index.js`)** importa los JSON como módulos (esbuild los empaqueta — sin KV/R2 obligatorio) y los sirve en `/v1/*` con CORS abierto, cache de borde y ETag `"v{data_version}"` → respuestas 304 cuando la app ya tiene la versión. La app móvil consulta `/v1/version` al abrir (~100 B) y solo descarga `/v1/all` si `data_version` subió.

**Detección vs publicación (no confundir):**
- *Detección* (automática): un Cron Trigger semanal (`crons = ["0 12 * * 1"]` en `wrangler.toml`) ejecuta el handler `scheduled`, que consulta el MEF vía `worker/src/mef.js` (port JS de `scraper_mef.py`). `GET /v1/status` reporta si hay semestre nuevo (`?live=1` fuerza chequeo en vivo). KV es **opcional**: sin él, `/v1/status` chequea en vivo cacheado 5 min.
- *Publicación* (manual, ~2 veces/año): transcribir el PDF nuevo, subir `DATA_VERSION`, regenerar, desplegar.
- Anti-falsos-positivos: solo se marca "nuevo" lo cronológicamente posterior al último semestre en `manifest.semestres` (los 14 PDF históricos 2019–2025 no disparan alarma).

**Modelo de datos** (detalle en `README_calendario.md`): `calendario` es tidy, 1 fila por año×semestre×mes×categoría×quincena = **60 filas/semestre**. Categorías: `JUBILADOS`, `GASTOS DE REPRESENTACION`, `GRUPO 1/2/3`. `grupos_entidades` mapea Grupo→Entidad (≈idéntico entre semestres). La consulta núcleo une ambos: dada una entidad, devuelve sus `fecha_pago` futuras. Dato recurrente: **MIDES (Min. de Desarrollo Social) = GRUPO 3.**

## App Flutter «¿Cuándo Pagan?» (en `lib/`, `test/`, `android/`, `ios/`, `web/`)

App **independiente y NO oficial** que consume el Worker. Posicionamiento crítico (riesgo de confusión ALTO porque las fechas son las oficiales reales): sin escudo/bandera/Marca País como identidad; el MEF se cita SOLO como "fuente pública"; "oficial" solo modifica al canal/sitio del MEF, nunca a la app. Disclaimer "no oficial" omnipresente (es Definition of Done). Ver §0.1 del spec.

```bash
flutter pub get
flutter test                              # suite completa (toda la lógica es testeable headless)
dart run build_runner build --delete-conflicting-outputs   # regenera app_database.g.dart (drift)
dart run tool/check_forbidden_deps.dart   # falla si entra una dep de tracking/analytics
flutter run -d chrome|<device>            # correr la app
# Regenerar la semilla offline (assets/seed/all.json) desde el pipeline:
python pipeline/build_dataset.py && python -c "import json,pathlib; d=pathlib.Path('data'); pathlib.Path('assets/seed/all.json').write_text(json.dumps({'manifest':json.loads((d/'manifest.json').read_text()),'calendario':json.loads((d/'calendario.json').read_text()),'grupos_entidades':json.loads((d/'grupos_entidades.json').read_text()),'xiii_mes':json.loads((d/'xiii_mes.json').read_text())},ensure_ascii=False))"
```

**Arquitectura (clean, feature-first, DIP estricto):** `lib/domain/` es **Dart puro — NO importa Flutter ni red** (entidades, enums, `logic/` con `calcularProximoPago`/`contador`/`detectarModificadas`, `search/`, interfaces de repositorio). `lib/data/` implementa contra el Worker (`WorkerApi`, ETag/304), drift (SQLite + semilla) y mappers. `lib/application/` orquesta con Riverpod. La UI (Plan 2) consume solo interfaces de dominio. Por eso la lógica de riesgo (off-by-one de fechas) se prueba sin levantar la app.

**Invariantes no negociables** (de §0.1 del spec): cero SDKs de tracking/analytics/ads (hay check de CI; `AD_ID` removido del manifiesto); todo "hoy"/contador usa `America/Panamá` **fijo** (UTC-5, sin DST), nunca la zona del dispositivo; `fecha_pago` **verbatim** (sin corrimiento por fin de semana/feriado); parsing de wire **tolerante** (`fromWire` nunca crashea, default seguro); capa de **siglas curada** en `assets/data/siglas_entidades.json` (separada del dato — "MIDES"→"Min. de Desarrollo Social"); **XIII Mes bajo demanda** (solo al buscarlo); modelo de fecha v1 = "solo fuente pública" (`Estimada` dormido). Targets: Android `minSdk 24`, iOS 16.

**Estado:** **Plan 1 (fundación headless) completo** — 34/34 tests, sin UI todavía. Antes de construir la UI (Plan 2), resolver las **4 costuras de integración** que dejó la revisión final (registradas en `.superpowers/sdd/progress.md`): unificar el decode de `/v1/all`; hilar la versión remota real a `proximoPago`; persistir el `Manifest` completo (no solo `ultimaDataVersion`); cablear el gate de CI de deps. `lib/main.dart` aún es boilerplate.

## Procesar un semestre nuevo (runbook anual)

Cuando `scraper_mef.py` (o `/v1/status`) reporte un semestre nuevo, seguir **ARQUITECTURA §8**. Resumen:
1. `scraper_mef.py --download` para bajar el PDF.
2. Transcribir la tabla al dict `DATOS` de `build_dataset.py` (revisar si la leyenda `GRUPOS` cambió).
3. Subir `DATA_VERSION` +1, agregar la clave a `SEMESTRES`, actualizar `FECHA_PUBLICACION`.
4. `python build_dataset.py` (debe pasar la validación de 60 filas).
5. `cd worker && npx wrangler deploy`.
6. Agregar la clave a `pipeline/processed.json`.

La app móvil se actualiza sola en la próxima apertura; solo se republica el APK si cambia el código.

## Convenciones del proyecto

- Español neutral panameño; horas en formato 12h AM/PM; fechas ISO `YYYY-MM-DD` en los datos.
- Las fechas de enero de un año inician su registro en diciembre del año anterior (por eso aparecen fechas del año previo en `inicio_registro`/`cierre_registro`/`retencion_ach`).
- Infraestructura a costo $0 (Cloudflare Workers free tier). Mantenerlo así.
