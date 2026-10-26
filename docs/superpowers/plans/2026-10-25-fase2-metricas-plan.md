# Fase 2 — Métricas de uso (Analytics Engine) + versión real de la app — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Contar con exactitud cada apertura de la app (sin IP, sin ID), consultable por CLI con `scripts/metricas.py`, y que la app muestre su versión real en Acerca.

**Architecture:** El Worker anota un data point en Workers Analytics Engine (dataset `cuandopagan_uso`) por cada `GET /v1/version`, **antes** del atajo 304. `/v1/version` pasa a `Cache-Control: no-cache` para que el navegador revalide siempre (304 barato) y cada apertura llegue al Worker; las respuestas de un Worker no quedan en la caché de borde, así que la única caché a vencer es la del navegador. La app agrega `?p=&v=&d=&push=` a esa llamada. Un script Python de solo stdlib consulta la SQL API de Analytics Engine.

**Tech Stack:** Cloudflare Workers (JS, `node:test` para tests, sin deps nuevas), Workers Analytics Engine, Flutter 3.41.4 + `package_info_plus`, Python 3 stdlib (`urllib`, `unittest`).

**Spec:** `docs/superpowers/specs/2026-10-25-push-recordatorios-y-metricas-design.md` (§5 Fase 2, §7). Invariantes: `docs/superpowers/specs/2026-06-26-app-cuando-pagan-design.md` §0.1.

## Global Constraints

- Solo dimensiones agregadas: **sin IP, user-agent, token ni ID** por usuario/instalación; nada de nonces ni timestamps por cliente en la URL.
- Ningún secreto en el repo (repo público): `CLOUDFLARE_ACCOUNT_ID` y el token de métricas solo por variable de entorno. `account_id` nunca en `wrangler.toml`.
- Costo $0 (Workers Free). Si Analytics Engine no estuviera disponible en Free, el fallback del spec es D1 con filas agregadas por día — eso es un replan, no una improvisación.
- La métrica jamás rompe la respuesta: sin binding (tests, `wrangler dev` sin AE) o si `writeDataPoint` lanza, el endpoint responde igual.
- Cero SDKs de tracking (`tool/check_forbidden_deps.dart` en verde). `package_info_plus` está permitido.
- Scripts en `scripts/`, multiplataforma (Mac/Windows, `platform.system()`, `pathlib`, UTF-8 explícito).
- La política de privacidad (in-app + `site/privacidad.html`) se actualiza en este mismo release.
- Español neutral panameño en todo texto visible. Gitflow: `feature/fase2-metricas` → `develop` → `release/0.5.0` → `main` + tag `v0.5.0`. Deploy manual, solo con aprobación explícita.

## Esquema de data points (fijo; Fase 3 lo reutiliza)

`index1` = evento. `blob1` = evento. Resto por evento:

| evento | blob2 | blob3 | blob4 | double1 | double2 |
|---|---|---|---|---|---|
| `apertura` | plataforma | versión app | push `'1'`/`'0'` | data_version | — |
| `push_alta` / `push_baja` / `push_realta` (Fase 3) | categoría | anticipación (`d0`/`d1`/`d3`) | — | — | — |
| `push_envio` (Fase 3) | tema | — | — | enviados | errores |

Conteos siempre con `SUM(_sample_interval)` (el muestreo adaptativo de AE).

## Review Focus

1. **Reapertura dentro de 5 min no se cuenta** (caché del navegador): `/v1/version` debe salir con `no-cache` y el conteo debe ocurrir también en la ruta 304 → test en Task 1.
2. **Clientes v0.4.0 sin query params** siguen contando como apertura con dimensiones `desconocido` → test en Task 1.
3. **Parámetros basura o enormes** (`v=<script>`, `d=-5`, `p=xbox`) no inflan la cardinalidad ni rompen: se normalizan a `otro`/`0` → test en Task 1.
4. **Binding ausente o que lanza** no tumba `/v1/version` → test en Task 1.
5. **`package_info_plus` falla o no hay versión** (tests, web sin `version.json`): la app no crashea y manda `v=desconocido` → test en Task 2.

---

### Task 1: Worker — evento `apertura` en Analytics Engine

**Files:**
- Create: `worker/src/metricas.js`
- Create: `worker/test/metricas.test.js`
- Modify: `worker/src/index.js` (fetch: conteo antes del 304; `/v1/version` no-cache)
- Modify: `worker/wrangler.toml` (binding)
- Modify: `worker/package.json` (`"test": "node --test test/"`)

**Interfaces:**
- Produces: `export function dimensionesApertura(url: URL): {plataforma: string, version: string, push: '0'|'1', dataVersion: number}`; `export function registrar(env, evento: string, blobs: string[], doubles?: number[]): void` (no-op si `env?.USO` falta; traga excepciones). Fase 3 usará `registrar` para los eventos push.
- Binding: `USO`, dataset `cuandopagan_uso`.

Reglas de normalización (exactas):
- `p` ∈ {`web`,`android`,`ios`} si no → `otro`; ausente → `desconocido`.
- `v` debe cumplir `/^\d{1,3}\.\d{1,3}\.\d{1,3}$/` si no → `otro`; ausente → `desconocido`.
- `push` === `'1'` → `'1'`, cualquier otra cosa → `'0'`.
- `d` entero en 0..9999 si no → `0`.

- [ ] **Step 1: Escribir los tests** en `worker/test/metricas.test.js` con `node:test` + `node:assert/strict` (importa solo `../src/metricas.js`; no importa `index.js`, que usa imports de JSON resueltos por esbuild):
  - `dimensionesApertura(new URL('https://x/v1/version?p=web&v=0.5.0&d=1&push=1'))` → `{plataforma:'web', version:'0.5.0', push:'1', dataVersion:1}`.
  - sin query → `{plataforma:'desconocido', version:'desconocido', push:'0', dataVersion:0}`.
  - `?p=xbox&v=<script>&d=-5&push=si` → `{plataforma:'otro', version:'otro', push:'0', dataVersion:0}`; `?d=99999` → `dataVersion:0`; `?v=1.2.3.4` → `'otro'`.
  - `registrar({USO:{writeDataPoint: fake}}, 'apertura', ['web','0.5.0','1'], [1])` llama `fake` una vez con `{indexes:['apertura'], blobs:['apertura','web','0.5.0','1'], doubles:[1]}`.
  - `registrar({}, ...)` y `registrar(undefined, ...)` no lanzan; `registrar({USO:{writeDataPoint(){throw new Error('x')}}}, ...)` no lanza.
- [ ] **Step 2:** `cd worker && npm test` → FAIL (módulo inexistente).
- [ ] **Step 3: Implementar `worker/src/metricas.js`** con esas dos funciones y el esquema de la tabla de arriba como comentario de cabecera. Sin `console.log` de la URL ni de headers.
- [ ] **Step 4: Cablear `index.js`:** en `fetch`, si `path === "/v1/version"`, llamar `registrar(env, 'apertura', [plataforma, version, push], [dataVersion])` **antes** del chequeo `If-None-Match`/304. Cambiar `/v1/version` a `Cache-Control: no-cache` (el 304 también debe llevar `Cache-Control: no-cache`). El resto de endpoints sin cambios.
- [ ] **Step 5: `wrangler.toml`:**
  ```toml
  # Métricas agregadas (sin IP ni ID). Esquema en src/metricas.js.
  [[analytics_engine_datasets]]
  binding = "USO"
  dataset = "cuandopagan_uso"
  ```
- [ ] **Step 6: Verificar:** `npm test` → PASS. `npx wrangler deploy --dry-run --outdir /tmp/x` → lista el binding `USO`. `npx wrangler dev --local` y:
  - `curl -si 'http://localhost:8787/v1/version?p=web&v=0.5.0&d=1&push=0'` → 200 JSON, `cache-control: no-cache`.
  - `curl -si -H 'If-None-Match: "v1"' 'http://localhost:8787/v1/version'` → 304, `cache-control: no-cache`.
  - `/v1/all` sigue 200/304 como antes.
- [ ] **Step 7: Commit** `feat(worker): evento apertura en Analytics Engine + /v1/version no-cache`.

### Task 2: App — parámetros de apertura y versión real visible

**Files:**
- Modify: `pubspec.yaml` (`package_info_plus`, `version: 0.5.0+10`)
- Modify: `lib/data/sync/dataset_sync.dart`
- Modify: `lib/main.dart` (`_crearSync`, Acerca, `showLicensePage`)
- Test: `test/data/sync/dataset_sync_test.dart`, `test/ui/estado_datos_texto_test.dart`

**Interfaces:**
- Consumes: query params de Task 1 (`p`, `v`, `d`, `push`).
- Produces: `Uri uriVersion(String baseUrl, {required String plataforma, required String appVersion, required int dataVersion, required bool push})` (top-level en `dataset_sync.dart`); `DatasetSync` gana params opcionales `String plataforma = 'web'`, `String appVersion = 'desconocido'`; `String textoVersionApp(String v)` en `main.dart` → `'App versión $v'`. Fase 3 cambiará el `push: false` fijo por el estado real.

- [ ] **Step 1: Tests:**
  - `uriVersion('https://w.test', plataforma:'web', appVersion:'0.5.0', dataVersion:1, push:false).toString()` == `'https://w.test/v1/version?p=web&v=0.5.0&d=1&push=0'`.
  - En `dataset_sync_test.dart`: un `MockClient` que captura la request de `/v1/version` con `DatasetSync(..., appVersion: '0.5.0')` tras `cargarInicial()` sobre semilla v1 → `req.url.queryParameters` == `{'p':'web','v':'0.5.0','d':'1','push':'0'}`. Los tests existentes siguen pasando (matchean por `url.path`).
  - Sin `appVersion` explícito → `v=desconocido`.
  - `textoVersionApp('0.5.0')` == `'App versión 0.5.0'`.
- [ ] **Step 2:** `flutter test test/data/sync test/ui` → FAIL.
- [ ] **Step 3: Implementar.** `_sincronizar` usa `uriVersion(_baseUrl, plataforma: _plataforma, appVersion: _appVersion, dataVersion: local, push: false)`. En `main.dart`, `_crearSync` obtiene la versión con `PackageInfo.fromPlatform()` envuelto en try/catch (→ `'desconocido'`, con `debugPrint('[sync] sin versión de app')`) y la plataforma con `kIsWeb ? 'web' : defaultTargetPlatform.name` (`android`/`iOS` → normalizar a minúsculas). Guardar la versión para la UI: Acerca muestra `textoVersionApp(v)` en la misma línea discreta que `textoEstadoDatos` (dos `Text` de 12 px, versión arriba), y `showLicensePage(applicationVersion: v)` reemplaza el `'0.3.2'` escrito a mano. Si aún no hay versión, no se muestra la línea de app.
- [ ] **Step 4:** `flutter pub get && flutter test && dart run tool/check_forbidden_deps.dart` → todo verde.
- [ ] **Step 5:** `flutter build web --release` y en `build/web` con `python3 -m http.server`: abrir, Acerca muestra `App versión 0.5.0`; licencias muestra 0.5.0; la request a `/v1/version` (contra producción, sin Task 1 desplegada) lleva los 4 params y la app no se rompe.
- [ ] **Step 6: Commit** `feat(app): parámetros de apertura en /v1/version + versión real en Acerca`.

### Task 3: `scripts/metricas.py`

**Files:**
- Create: `scripts/metricas.py`
- Create: `scripts/test_metricas.py`

**Interfaces:**
- Consumes: esquema de data points (tabla de arriba), dataset `cuandopagan_uso`.
- Env: `CLOUDFLARE_ACCOUNT_ID`, `CF_METRICAS_TOKEN` (token con permiso *Account → Account Analytics → Read*). Faltan → mensaje en español explicando cómo crearlo y `exit 2`. Nunca imprimir el token.
- Produces: `consultas(dias: int) -> dict[str, str]` (claves `aperturas_dia`, `por_version`, `push_altas_bajas`, `envios`); `formatear_tabla(columnas: list[str], filas: list[dict]) -> str`; `main(argv) -> int`. CLI: `python scripts/metricas.py [--dias 30]`.

- [ ] **Step 1: Tests** (`unittest`, sin red):
  - `consultas(30)['aperturas_dia']` contiene `FROM cuandopagan_uso`, `index1 = 'apertura'`, `SUM(_sample_interval)`, `INTERVAL '30' DAY` y una columna `con_push` (`sumIf(_sample_interval, blob4 = '1')`); agrupa por `toStartOfDay(timestamp)` y termina en `FORMAT JSON`.
  - `consultas(7)` usa `INTERVAL '7' DAY` en las cuatro consultas; `--dias` fuera de 1..90 → error de argparse (AE guarda ~3 meses).
  - `formatear_tabla(['dia','aperturas'], [{'dia':'2026-10-26','aperturas':3}])` produce encabezado, separador y fila alineados; con `[]` → `'(sin datos)'`.
  - `main([])` sin variables de entorno → devuelve 2 y el mensaje menciona `CF_METRICAS_TOKEN`.
  - Con `urllib.request.urlopen` parcheado devolviendo `{"data":[...]}`, `main([])` → 0 e imprime los 4 títulos de sección; el `Request` lleva `Authorization: Bearer <token>` y va a `.../accounts/<id>/analytics_engine/sql`.
- [ ] **Step 2:** `python3 -m unittest scripts/test_metricas.py` → FAIL.
- [ ] **Step 3: Implementar** solo con stdlib. Al inicio: `platform.system()` y `sys.stdout.reconfigure(encoding='utf-8')`. Errores HTTP → mensaje con código y cuerpo recortado (sin headers), `exit 1`. Fechas mostradas en `America/Panama` (restar 5 h; sin DST) — dejarlo explícito en el encabezado: "Días en hora de Panamá".
- [ ] **Step 4:** tests → PASS; `python3 scripts/metricas.py --help` funciona.
- [ ] **Step 5: Commit** `feat(scripts): metricas.py consulta Analytics Engine por CLI`.

### Task 4: Política de privacidad + docs

**Files:**
- Modify: `site/privacidad.html` (lead/meta si aplica, punto 4, fecha `Última actualización: octubre 2026`)
- Modify: `lib/main.dart` (`PrivacidadScreen` punto 5, sección "Privacidad" de Acerca)
- Modify: `CLAUDE.md` (Estado: métricas + cómo correr `scripts/metricas.py`), `README.md` si documenta endpoints.

Copia exacta a agregar (site, punto 4, nuevo párrafo tras el de Cloudflare Web Analytics; in-app, al final del punto 5):

> **Conteo anónimo de aperturas:** cada vez que abres la app, esta avisa a nuestro servicio la plataforma (web, Android o iOS), la versión de la app y la versión del calendario que tiene. Con eso contamos cuántas aperturas hay por día. No guardamos tu dirección IP, ni un identificador tuyo o de tu dispositivo, ni nada que permita saber quién eres o seguirte.

Y reemplazar "La app móvil no incluye ninguna analítica." por "Fuera de este conteo anónimo, la app no incluye ninguna analítica." (site e in-app). En Acerca, "Privacidad": `'No pedimos cuenta ni datos personales. Contamos aperturas de forma anónima (sin IP ni identificadores). Tus preferencias se quedan en tu dispositivo.'`

- [ ] **Step 1:** Editar los textos. `grep -n "app móvil no incluye" lib/main.dart site/privacidad.html` → sin resultados.
- [ ] **Step 2:** `flutter test` verde.
- [ ] **Step 3: Commit** `docs(privacidad): informar el conteo anónimo de aperturas`.

### Task 5: Release 0.5.0 (controller; deploy solo con aprobación explícita)

- [ ] **Step 1:** Revisión final de toda la rama. Grep anti-secretos del diff (`account_id`, IDs de cuenta, `Bearer `, tokens).
- [ ] **Step 2 (aprobación):** Pre-mortem al usuario. Orden: Worker primero (los clientes 0.4.0 sin params cuentan como `desconocido`), luego web.
- [ ] **Step 3:** `CLOUDFLARE_ACCOUNT_ID=… npx wrangler deploy`. Verificar: `/v1/version` 200 con `cache-control: no-cache`; 304 con ETag; `/v1/all` 120 filas; `/` y `/privacidad/` siguen en Pages.
- [ ] **Step 4:** El usuario crea el token de solo lectura (guiado; se guarda en su shell, nunca en el repo). `python scripts/metricas.py --dias 1` → tabla (puede tardar ~1 min en aparecer). Si AE no está disponible en Free (error de la SQL API o del deploy), parar y replanear a D1.
- [ ] **Step 5:** `release/0.5.0`, build web + `cp site/privacidad.html build/web/privacidad/index.html` + `wrangler pages deploy`. `version.json` = 0.5.0.
- [ ] **Step 6 — aceptación §7:** abrir la app N=3 veces controladas (navegador limpio, recargas separadas) → `metricas.py --dias 1` muestra ≥3 aperturas nuevas con `v=0.5.0`, `p=web`. Acerca muestra `App versión 0.5.0`.
- [ ] **Step 7:** merge a `main`, tag `v0.5.0`, back-merge a `develop`, push.
