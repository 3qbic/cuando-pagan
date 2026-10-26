# Fase 1 — Worker desplegado + sync web — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que `cuandopagan.3qbic.com/v1/*` lo sirva el Worker y que la app web descargue y guarde el calendario nuevo cuando suba `data_version`, sin redeploy y sin perder el modo offline.

**Architecture:** Worker `calendario-pago-pa` desplegado con una Worker Route `cuandopagan.3qbic.com/v1/*` en la zona `3qbic.com`; tiene precedencia sobre Pages solo en `/v1/*`. En la app web, un `DatasetSync` nuevo (capa `lib/data/`) arranca con la mejor copia local disponible: el JSON de `/v1/all` cacheado en `SharedPreferences` si su `data_version` supera la de la semilla, y si no, la semilla. Luego sincroniza en segundo plano: `/v1/version` y, si subió, `/v1/all`, que se valida y se guarda. `main.dart` deja de decodificar por su cuenta y usa una sola función `datasetDesdeAllJson`.

**Decisión de alcance (de Claude):** la app web **no** usa el repositorio drift de Plan 1. Drift en web exige `sqlite3.wasm` y `drift_worker.js`, y la UI de hoy no lo consume. El repo drift (`CalendarioRepositoryImpl`, `WorkerApi`, `SyncController`) **no se toca** y queda para la app Android; las costuras #1–#3 de `.superpowers/sdd/progress.md` siguen abiertas *para ese camino*. La #4 (CI) se cierra aquí.

**Tech Stack:** Flutter 3.41.4 (web), `http` + `http/testing` (MockClient), `shared_preferences`, Cloudflare Workers + wrangler 4, Python 3 (pipeline).

**Spec:** `docs/superpowers/specs/2026-10-25-push-recordatorios-y-metricas-design.md` (Fase 1) → `docs/superpowers/specs/2026-07-05-worker-api-deploy-spec.md` (detalle de la Fase 1).

## Global Constraints

- **REPO PÚBLICO (`3qbic/cuando-pagan`):** cero secretos en git. No se commitean tokens, API keys, `account_id` personales, `.dev.vars`, `.env`, llaves `.json` de service accounts ni salidas de `wrangler whoami`. El `account_id` de wrangler se pasa por la variable de entorno `CLOUDFLARE_ACCOUNT_ID` al desplegar, **no** en `wrangler.toml`. Antes de cada commit: `git diff --cached | grep -iE "token|secret|api[_-]?key|BEGIN PRIVATE|account_id"` debe salir vacío (o solo con nombres de variable, sin valores).
- Invariantes §0.1: "hoy" en `America/Panama` fijo; `fecha_pago` verbatim; parsing tolerante (nunca crashear por un JSON raro, sino caer a un default seguro); cero SDKs de tracking (`dart run tool/check_forbidden_deps.dart` verde).
- Offline-first: sin red o con el Worker caído, la app abre con la semilla o con la última copia cacheada, **sin pantallas de error**.
- Costo $0 (Workers Free). Deploy **manual** (el usuario declinó auto-deploy): el workflow de CI solo corre tests, **no despliega**.
- Gitflow: rama `feature/fase1-worker-sync` desde `develop`; al final, `release/0.4.0` → `main` + tag `v0.4.0`, y merge de vuelta a `develop`.
- Español neutral panameño en textos y comentarios, como el código existente.

## Review Focus

1. **`/v1/version` devuelve HTML** (el estado de hoy, o un error del Worker con la página de Pages): la sync no debe crashear ni cachear nada, y debe dejar `EstadoDatos.errorRed` con el motivo. → test en Task 3.
2. **`/v1/all` válido pero incompleto o corrupto** (`calendario` vacío, sin `manifest` o con `data_version` menor a la local): no se cachea y no reemplaza los datos buenos. → test en Task 3.
3. **Caché viejo con semilla más nueva** (un deploy de la web trae una semilla v2 y el caché local tiene v1): gana la semilla. → test en Task 3.
4. **Caché local corrupto en SharedPreferences** (JSON truncado): se descarta, se usa la semilla y no hay crash. → test en Task 3.
5. **La Worker Route intercepta solo `/v1/*`**: `/`, `/privacidad/` y los assets siguen viniendo de Pages. → verificación con curl en Task 5.

---

### Task 1: Pipeline — históricos en `processed.json`

**Files:**
- Modify: `pipeline/processed.json`

- [ ] **Step 1:** Correr `/Library/Frameworks/Python.framework/Versions/3.13/bin/python3 pipeline/scraper_mef.py`. Expected: lista 2019-S1…2025-S2 como `[NUEVO]`.
- [ ] **Step 2:** Agregar a `procesados` las 14 claves `2019-S1` … `2025-S2` (orden cronológico, antes de `2026-S1`). En `descripcion`, aclarar que los históricos se marcan como procesados para no disparar alarmas aunque sus datos no estén en `data/`.
- [ ] **Step 3:** Repetir el Step 1. Expected: ningún `[NUEVO]` y el mensaje de "sin pendientes" del script.
- [ ] **Step 4:** Commit `chore(pipeline): marcar semestres históricos 2019–2025 como procesados`.

### Task 2: `datasetDesdeAllJson` — un solo decode de `/v1/all`

**Files:**
- Create: `lib/data/dataset.dart`
- Modify: `lib/main.dart` (borrar la clase `Dataset` y el cuerpo de decode de `_cargar()`, ~líneas 133–152; importar desde `lib/data/dataset.dart`)
- Test: `test/data/dataset_test.dart`

**Interfaces:**
- Produces:
  - `class Dataset { final Manifest manifest; final List<EntradaCalendario> calendario; final List<Entidad> entidades; final List<XiiiMes> xiii; }` (igual que la de hoy en `main.dart`, movida).
  - `Dataset datasetDesdeAllJson(Map<String, dynamic> all, Map<String, List<String>> siglas)`: misma lógica que el `_cargar()` actual, con `xiii` ordenado por `fechaDate`. Lanza `FormatException` si faltan las claves `manifest`, `calendario`, `grupos_entidades` o `xiii_mes`, o si no son del tipo esperado.
  - `bool payloadValido(Map<String, dynamic> all)`: true si `datasetDesdeAllJson` no lanza **y** `calendario` no está vacío.

- [ ] **Step 1: Tests que fallan** en `test/data/dataset_test.dart`:
  - `'decodifica la semilla real'`: lee `assets/seed/all.json` con `File`, `datasetDesdeAllJson(json, {})` → `calendario.length == 120`, `manifest.dataVersion == 1`, `xiii` ordenado ascendente.
  - `'payload sin calendario no es válido'`: `payloadValido({...seed, 'calendario': []})` es `false`.
  - `'payload sin manifest lanza FormatException'`: `expect(() => datasetDesdeAllJson({'calendario': []}, {}), throwsFormatException)`.
  - `'HTML decodificado no es válido'`: `payloadValido({'html': '<!DOCTYPE html>'})` es `false`.
- [ ] **Step 2:** `flutter test test/data/dataset_test.dart` → FAIL (no existe el archivo).
- [ ] **Step 3:** Implementar `lib/data/dataset.dart` y hacer que `main.dart` `_cargar()` llame a `datasetDesdeAllJson`. Por ahora sigue leyendo la semilla; la Task 4 lo reemplaza.
- [ ] **Step 4:** `flutter test` → todo verde (57 + 4).
- [ ] **Step 5:** Commit `refactor(data): decode único de /v1/all en datasetDesdeAllJson`.

### Task 3: `DatasetSync` — caché local + sync con el Worker

**Files:**
- Create: `lib/data/sync/dataset_sync.dart`
- Test: `test/data/sync/dataset_sync_test.dart`

**Interfaces:**
- Consumes: `datasetDesdeAllJson`, `payloadValido` (Task 2); `kWorkerBaseUrl` (`lib/core/constants/umbrales.dart`).
- Produces:
  - `enum OrigenDatos { semilla, cache, sincronizado }`
  - `class EstadoDatos { final OrigenDatos origen; final int dataVersion; final String? ultimoError; final DateTime? ultimoIntento; }`
  - `class DatasetSync`:
    - constructor `DatasetSync({required http.Client client, required SharedPreferences prefs, required Future<Map<String, dynamic>> Function() leerSemilla, required Map<String, List<String>> siglas, String baseUrl = kWorkerBaseUrl})`
    - `Future<Dataset> cargarInicial()`: elige entre el caché y la semilla y fija `estado`.
    - `Future<Dataset?> sincronizar()`: devuelve el `Dataset` nuevo si descargó y guardó uno; `null` si no hubo cambio o hubo error. **Nunca lanza.**
    - `EstadoDatos get estado`
  - Claves de prefs: `cacheAllJson` (String, el JSON crudo de `/v1/all`) y `cacheDataVersion` (int).

**Reglas** (las que deciden los tests):
- `cargarInicial`: si `cacheDataVersion > semilla.manifest.data_version` **y** el caché decodifica y `payloadValido`, usar el caché (`origen=cache`). En cualquier otro caso usar la semilla (`origen=semilla`). Si el caché era corrupto, borrar las dos claves.
- `sincronizar`: `GET {baseUrl}/v1/version`. Si no es 200, si el `Content-Type` no contiene `application/json` o si el `jsonDecode` falla, termina con `ultimoError` y devuelve `null`. Si `data_version` remota ≤ la local, `null`. Si es mayor: `GET /v1/all` con `If-None-Match: "v{local}"`. Si responde 304, `null`. Si responde 200, `payloadValido` y `manifest.data_version` > local, guardar en prefs, `origen=sincronizado` y devolver el `Dataset`. Si no, `ultimoError` y `null`.
- Timeout de 8 s por request (`.timeout`). Un timeout cuenta como error y no lanza.
- Cada error se reporta con `debugPrint('[sync] …')`. Así se reemplaza el `catch (_)` mudo.

- [ ] **Step 1: Tests que fallan** en `test/data/sync/dataset_sync_test.dart`, con `MockClient` y `SharedPreferences.setMockInitialValues`. La semilla se arma desde `assets/seed/all.json` (v1); un "remoto v2" es la misma semilla con `manifest.data_version = 2`.
  - `'sin caché arranca con la semilla'` → `origen == semilla`, `dataVersion == 1`.
  - `'caché v2 válido gana sobre semilla v1'` → `origen == cache`, `dataVersion == 2`.
  - `'semilla más nueva que el caché gana la semilla'` (caché v1 con semilla v2) → `origen == semilla`.
  - `'caché corrupto se descarta'` (`cacheAllJson = '{"manif'`, `cacheDataVersion = 5`) → `origen == semilla` y las claves quedan borradas.
  - `'version devuelve HTML: no crashea ni cachea'` (200, `text/html`, `<!DOCTYPE html>`) → `sincronizar()` devuelve `null`, `estado.ultimoError` no nulo, `prefs.getString('cacheAllJson')` nulo.
  - `'remoto igual al local no descarga /v1/all'` → el MockClient falla el test si recibe `/v1/all`.
  - `'remoto mayor descarga, valida y cachea'` → devuelve un Dataset con `dataVersion 2`, `origen == sincronizado`, `cacheDataVersion == 2`, y el request a `/v1/all` lleva `If-None-Match: "v1"`.
  - `'all con calendario vacío no reemplaza'` → `null`, sin caché.
  - `'all con data_version menor no reemplaza'` (version dice 3, all trae 1) → `null`.
  - `'timeout no lanza'` (MockClient que tarda más que el timeout; inyectar un timeout corto como parámetro opcional `Duration timeout = const Duration(seconds: 8)`) → `null` y `ultimoError` no nulo.
- [ ] **Step 2:** `flutter test test/data/sync/dataset_sync_test.dart` → FAIL.
- [ ] **Step 3:** Implementar `DatasetSync`.
- [ ] **Step 4:** `flutter test` → verde.
- [ ] **Step 5:** Commit `feat(data): DatasetSync offline-first con caché de /v1/all y validación`.

### Task 4: Cablear la sync en la UI + estado visible + CI

**Files:**
- Modify: `lib/main.dart` (`_cargar()`, `_RootPageState._init()`, `AcercaDeScreen`)
- Create: `.github/workflows/ci.yml`
- Test: `test/ui/estado_datos_texto_test.dart`

**Interfaces:**
- Consumes: `DatasetSync`, `EstadoDatos`, `OrigenDatos` (Task 3).
- Produces: `String textoEstadoDatos(EstadoDatos e)`, pública y top-level en `main.dart`, con el patrón de `progresoAnilloDecimo`.

- [ ] **Step 1: Test que falla** `test/ui/estado_datos_texto_test.dart`:
  - `semilla, v1` → `'Datos incluidos en la app · versión 1'`
  - `cache, v2` → `'Datos guardados · versión 2'`
  - `sincronizado, v2` → `'Actualizado · versión 2'`
  - con `ultimoError` no nulo → el texto anterior + `' · sin conexión con el servidor'`
- [ ] **Step 2:** Correrlo → FAIL.
- [ ] **Step 3:** Implementar:
  - `_init()`: crear `DatasetSync` (con `http.Client()`, `SharedPreferences`, semilla vía `rootBundle`, siglas de `assets/data/siglas_entidades.json`), `await cargarInicial()` y pintar. Luego `sincronizar()` **sin await** en el primer frame. Si devuelve un Dataset, `setState` para reemplazar `_ds` y `_ops` y re-resolver `_sel` con `Seleccion.fromToken` (si el token ya no existe, dejar `_sel = null`, sin crash).
  - `AcercaDeScreen`: una línea discreta con `textoEstadoDatos(sync.estado)`. Pasar el estado por constructor.
  - `.github/workflows/ci.yml`: en `push` y `pull_request` a `main`/`develop`, `ubuntu-latest`, `subosito/flutter-action@v2` con `flutter-version: 3.41.4`, luego `flutter pub get`, `dart run tool/check_forbidden_deps.dart`, `flutter test`. **Sin secrets y sin deploy.**
- [ ] **Step 4:** `flutter test` y `flutter analyze` (sin errores nuevos) → verde. Correr `flutter run -d chrome` y confirmar que abre con la semilla. Con el Worker aún no desplegado, el estado en Acerca debe decir `· sin conexión con el servidor`.
- [ ] **Step 5:** Commit `feat(app): sync con el Worker al abrir + estado de datos en Acerca + CI de tests`.

### Task 5: Desplegar el Worker + route + verificación en producción

**Files:**
- Modify: `worker/wrangler.toml` (agregar `routes = [{ pattern = "cuandopagan.3qbic.com/v1/*", zone_name = "3qbic.com" }]`; **sin** `account_id`)
- Modify: `CLAUDE.md` (sección "Estado": v0.4.0, Worker desplegado, la web sincroniza; quitar "Plan 1… sin UI")
- Modify: `pubspec.yaml` (`version: 0.4.0+9`)

- [ ] **Step 1: Pre-mortem** (escrito en el reporte de la tarea):

  | Qué puede salir mal | Cómo lo evito / verifico |
  |---|---|
  | La route tapa la SPA o `/privacidad/` | El patrón es solo `/v1/*`; curl a `/` y `/privacidad/` después |
  | Deploy a la cuenta equivocada (hay 3) | `CLOUDFLARE_ACCOUNT_ID` de 3QBIC por env; `wrangler whoami` antes |
  | Se filtra un secreto al repo público | Grep del diff (Global Constraints); el Worker no tiene secretos en esta fase |
  | Los datos del Worker difieren de la semilla | Comparar `curl /v1/all` contra `assets/seed/all.json` (mismo `data_version` y 120 filas) |
  | La app vieja (v0.3.2) se rompe con `/v1` vivo | v0.3.2 no llama a `/v1`; no le afecta |
  | Rollback | Quitar `routes` del toml y `npx wrangler deploy` (la route desaparece y `/v1/*` vuelve a Pages), o `npx wrangler rollback`; Pages no se toca |

- [ ] **Step 2:** `cd worker && npx wrangler deploy --dry-run` → bundle OK, ruta listada.
- [ ] **Step 3:** **El usuario aprueba** el deploy a producción (punto de control; mostrarle el pre-mortem). Después: `CLOUDFLARE_ACCOUNT_ID=<id 3QBIC> npx wrangler deploy`.
- [ ] **Step 4: Verificar** (todas deben cumplirse):
  - `curl -si https://cuandopagan.3qbic.com/v1/version` → `200`, `content-type: application/json`, `data_version: 1`.
  - `curl -si -H 'If-None-Match: "v1"' https://cuandopagan.3qbic.com/v1/version` → `304`.
  - `curl -s https://cuandopagan.3qbic.com/v1/all | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(d['calendario']))"` → `120`.
  - `curl -s https://cuandopagan.3qbic.com/ | grep -c flutter_bootstrap` → `1` (la SPA sigue en Pages).
  - `curl -si https://cuandopagan.3qbic.com/privacidad/` → `200` HTML.
  - `curl -s 'https://cuandopagan.3qbic.com/v1/status?live=1'` → JSON con `hay_nuevo: false`.
- [ ] **Step 5:** Release web (con aprobación del usuario): `release/0.4.0`, `flutter build web --release && cp site/privacidad.html build/web/privacidad/index.html && cd worker && npx wrangler pages deploy ../build/web --project-name=cuandopagan --branch=main --commit-dirty=true`. Verificar `curl -s https://cuandopagan.3qbic.com/version.json` → `"version":"0.4.0"`, y en el navegador que Acerca diga `Datos incluidos en la app · versión 1`, sin "sin conexión".
- [ ] **Step 6:** Commit de release, merge a `main` + tag `v0.4.0` y merge a `develop`. Antes del push, correr el grep anti-secretos sobre `git log -p origin/main..main`.
