# Fase 3 — Recordatorios push (FCM web) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Quien tiene favorito en la web activa "Recordarme cuando me paguen", elige 0/1/3 días antes, y recibe un push de FCM aunque tenga la pestaña cerrada; release 0.6.0.

**Architecture:** Sin base de usuarios: un tema de FCM por categoría × anticipación (15 temas). La app obtiene el token FCM en el navegador y le pide al Worker `POST /v1/push/alta|baja`; el Worker suscribe o desuscribe el token con la API de temas de Google y **no lo guarda**. Un cron diario (7:00 AM Panamá) calcula con una función pura qué temas tienen pago hoy+N y envía por FCM HTTP v1 con un token OAuth firmado (RS256, WebCrypto).

**Tech Stack:** Cloudflare Worker (JS, `node --test`), WebCrypto, FCM HTTP v1 + IID topic API; Flutter 3.41.4 web con `firebase_core` + `firebase_messaging`, `shared_preferences`, `http`.

**Spec:** `docs/superpowers/specs/2026-10-25-push-recordatorios-y-metricas-design.md` §5 «Fase 3» (y §3, §4, §7). Contexto vinculante: §0.1 de `docs/superpowers/specs/2026-06-26-app-cuando-pagan-design.md`.

## Global Constraints

- Repo **público**: nunca commitear service account, llaves privadas, `ADMIN_TOKEN` ni account_id. Secretos solo con `wrangler secret put`. La config web de Firebase (`apiKey`, `projectId`, `appId`, `messagingSenderId`) y la llave VAPID **pública** sí se commitean: son públicas por diseño.
- El Worker **nunca** registra el token FCM: ni en logs (`console.*`), ni en KV, ni en Analytics Engine, ni en el cuerpo de un error.
- Hora `America/Panama` fija (UTC-5, sin DST). `fecha_pago` verbatim (sin correr fines de semana/feriados).
- Cero SDKs de tracking: **no** `firebase_analytics` (ni por arrastre). `dart run tool/check_forbidden_deps.dart` en verde.
- El permiso de notificaciones se pide **solo al tocar el botón**; tras un "no" no se vuelve a pedir solo.
- Textos: tono "no oficial"; toda notificación lleva "(fuente: MEF)" y "referencial" (quincena) o "aproximada" (décimo).
- Anticipaciones fijas `{0, 1, 3}`; por defecto al activar: `1`.
- Temas: `{slug}-d{N}` con slugs `jubilados`, `gastosrep`, `grupo1`, `grupo2`, `grupo3` (wire → slug: `JUBILADOS`, `GASTOS DE REPRESENTACION`, `GRUPO 1`, `GRUPO 2`, `GRUPO 3`).
- Cron único `0 12 * * *` (7:00 AM Panamá); los lunes además corre la verificación del MEF existente.
- Costo $0 (Workers Free, Firebase Spark). Gitflow `feature/fase3-push` → `develop` → `release/0.6.0` → `main` + tag.
- Deploy, merge y push solo con aprobación explícita del usuario y pre-mortem.
- Español neutral panameño; horas 12h AM/PM.

## Review Focus

1. **El cron corre a las 12:00 UTC y "hoy" debe ser la fecha de Panamá**; un `Date` cerca de medianoche UTC (p. ej. `2026-10-27T04:59Z`) debe dar `2026-10-26`. → test en Task 1.
2. **Firebase no disponible** (navegador sin soporte, bloqueado, init falla, o tests sin Firebase): la app abre y funciona igual; la tarjeta de recordatorio no aparece o muestra "no disponible". → test en Task 5 y Task 6.
3. **Token que rota** (`getToken` devuelve otro distinto al guardado): la app da de baja nada (el viejo ya no sirve), hace alta como `realta` y guarda el nuevo. → test en Task 5.
4. **Cambio de favorito o de grupo entre semestres con push activo**: baja de los temas viejos y alta de los nuevos, en ese orden; quitar el favorito apaga el push. → test en Task 5.
5. **Cuerpo malformado o malicioso en `/v1/push/*`** (JSON roto, categoría desconocida, anticipación 2, token de 10 KB, token con `<script>`): 400 sin eco del token; error de Google → 502 y la app conserva su estado anterior. → test en Task 3 y Task 5.

---

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `worker/src/avisos.js` (nuevo) | Funciones puras: fecha Panamá, temas, qué avisos salen hoy y con qué texto |
| `worker/src/fcm.js` (nuevo) | OAuth (JWT RS256), suscribir/desuscribir temas, enviar a un tema |
| `worker/src/push.js` (nuevo) | Handlers HTTP de alta/baja/cron-manual y la corrida diaria |
| `worker/src/index.js` | Ruteo, CORS con POST, `scheduled` diario |
| `worker/wrangler.toml` | Cron diario |
| `lib/domain/logic/tema_push.dart` (nuevo) | Tema por categoría × anticipación (Dart puro) |
| `lib/data/push/push_api.dart` (nuevo) | Cliente HTTP de `/v1/push/alta|baja` |
| `lib/data/push/push_plataforma.dart` (nuevo) | Interfaz del push del navegador + implementación nula |
| `lib/data/push/push_plataforma_web.dart` (nuevo) | Implementación con `firebase_messaging` |
| `lib/application/push_controller.dart` (nuevo) | Estado y orquestación: activar, apagar, cambiar anticipaciones, reconciliar |
| `lib/ui/recordatorio_card.dart` (nuevo) | Tarjeta del Home |
| `lib/firebase_options.dart` (nuevo, público) | Config web de Firebase |
| `web/firebase-messaging-sw.js` (nuevo) | SW de FCM (mensajes en segundo plano) |
| `lib/main.dart` | Wiring: init Firebase guardado, tarjeta, flag `push` en apertura, reconciliar tras sync, privacidad in-app |
| `site/privacidad.html`, `ARQUITECTURA.md`, `CLAUDE.md` | Textos y docs |

---

### Task 1: Worker — lógica pura de avisos

**Files:**
- Create: `worker/src/avisos.js`
- Test: `worker/test/avisos.test.js`

**Interfaces:**
- Produces:
  - `fechaPanama(date: Date) -> string` (`'YYYY-MM-DD'`, UTC−5 fijo)
  - `ANTICIPACIONES = [0, 1, 3]`
  - `SLUG = { 'JUBILADOS': 'jubilados', 'GASTOS DE REPRESENTACION': 'gastosrep', 'GRUPO 1': 'grupo1', 'GRUPO 2': 'grupo2', 'GRUPO 3': 'grupo3' }`
  - `NOMBRE = { 'JUBILADOS': 'Jubilados', 'GASTOS DE REPRESENTACION': 'Gastos de representación', 'GRUPO 1': 'Grupo 1', 'GRUPO 2': 'Grupo 2', 'GRUPO 3': 'Grupo 3' }`
  - `tema(categoriaWire: string, n: number) -> string | null` (null si categoría o n fuera de lista)
  - `semestreDe(iso: string) -> string` (`'2026-S2'`)
  - `avisosDelDia(hoy: string, calendario: Row[], xiii: Row[], semestres: string[]) -> Array<{tema, titulo, cuerpo}>`, ordenado por `tema`, un elemento por tema como máximo.

Textos exactos (`{cat}` = `NOMBRE[...]`, `{fecha}` = día de semana + día + mes en minúscula, p. ej. `jueves 30 de octubre`; arreglos fijos de nombres, sin `Intl`):

| Caso | título | cuerpo |
|---|---|---|
| quincena d0 | `Hoy te pagan 💸` | `{cat} · {fecha} · fecha referencial (fuente: MEF)` |
| quincena d1 | `Mañana te pagan 💸` | igual |
| quincena d3 | `Faltan 3 días para tu pago` | igual |
| décimo d0 | `Hoy se espera tu décimo` | `{cat} · {fecha} · fecha aproximada (fuente: MEF)` |
| décimo d1 | `Se espera tu décimo mañana 💰` | igual |
| décimo d3 | `Faltan 3 días para tu décimo (fecha aproximada)` | igual |
| quincena + décimo mismo día | título de la quincena | `{cat} · {fecha} · quincena y décimo (aprox.) · fecha referencial (fuente: MEF)` |

Reglas: la quincena va al tema de su categoría; el décimo (`xiii_mes.fecha_aprox`) va a los temas de **las 5 categorías** (es universal, como en `calcularProximoEvento`). Si `semestreDe(hoy)` no está en `semestres`, devuelve `[]`.

- [ ] **Step 1: Write the failing tests** (`node:test`, fixtures mínimas en el test, no el JSON real salvo donde se indica)
  - `fechaPanama`: `new Date('2026-10-27T04:59:00Z')` → `'2026-10-26'`; `'2026-10-27T05:00:00Z'` → `'2026-10-27'`; `'2026-10-26T12:00:00Z'` (hora del cron) → `'2026-10-26'`.
  - `tema('GRUPO 3', 1)` → `'grupo3-d1'`; `tema('GASTOS DE REPRESENTACION', 0)` → `'gastosrep-d0'`; `tema('GRUPO 4', 1)` → `null`; `tema('GRUPO 3', 2)` → `null`.
  - `semestreDe('2026-06-30')` → `'2026-S1'`; `semestreDe('2026-07-01')` → `'2026-S2'`.
  - d0/d1/d3: fila `GRUPO 3` con `fecha_pago: '2026-10-30'`; `hoy='2026-10-30'` → `[{tema:'grupo3-d0', titulo:'Hoy te pagan 💸', cuerpo:'Grupo 3 · viernes 30 de octubre · fecha referencial (fuente: MEF)'}]`; `hoy='2026-10-29'` → tema `grupo3-d1`; `hoy='2026-10-27'` → tema `grupo3-d3`; `hoy='2026-10-28'` → `[]`.
  - cambio de mes: pago `'2026-11-02'`, `hoy='2026-10-30'` → `grupo3-d3`.
  - cambio de año: pago `'2027-01-02'`, `hoy='2026-12-30'`, `semestres=['2026-S2','2027-S1']` → `grupo3-d3` con `sábado 2 de enero`.
  - décimo solo: xiii `'2026-12-04'`, `hoy='2026-12-03'` → 5 avisos (`gastosrep-d1`, `grupo1-d1`, `grupo2-d1`, `grupo3-d1`, `jubilados-d1`), título `Se espera tu décimo mañana 💰`.
  - fusión: `GRUPO 3` pago `'2026-12-04'` + xiii `'2026-12-04'`, `hoy='2026-12-04'` → exactamente un aviso `grupo3-d0` con el cuerpo de "quincena y décimo".
  - duplicado: dos filas iguales del mismo tema y fecha → un solo aviso.
  - semestre ausente: `hoy='2027-02-01'`, `semestres=['2026-S1','2026-S2']` → `[]`.
  - con los datos reales (`import calendario from '../src/data/calendario.json' with { type: 'json' }`): ningún tema fuera de los 15 válidos para todos los días de 2026.

- [ ] **Step 2: Run to verify they fail** — `cd worker && npm test` → FAIL (módulo no existe).
- [ ] **Step 3: Implement `worker/src/avisos.js`** — aritmética de fechas con `Date.UTC` sobre `YYYY-MM-DD` (nunca la zona local del runtime).
- [ ] **Step 4: Run** — `npm test` → todos PASS.
- [ ] **Step 5: Commit** — `git add worker/src/avisos.js worker/test/avisos.test.js && git commit -m "feat(worker): lógica pura de avisos push (temas, fechas Panamá, textos)"`

---

### Task 2: Worker — cliente FCM (OAuth RS256, temas, envío)

**Files:**
- Create: `worker/src/fcm.js`
- Test: `worker/test/fcm.test.js`

**Interfaces:**
- Consumes: nada de Task 1.
- Produces (todas reciben `fetchImpl` inyectable para tests; por defecto `fetch`):
  - `cuentaDeServicio(env) -> {client_email, private_key, project_id} | null` — parsea `env.FCM_SERVICE_ACCOUNT` (JSON); `null` si falta o es inválido.
  - `tokenOAuth(cuenta, {fetchImpl, ahora}) -> Promise<string>` — JWT RS256 (`iss`=client_email, `scope`=`https://www.googleapis.com/auth/firebase.messaging`, `aud`=`https://oauth2.googleapis.com/token`, `iat`, `exp`=iat+3600) firmado con `crypto.subtle` (PKCS#8 desde el PEM), canjeado en `https://oauth2.googleapis.com/token` (`grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer`). Cachea en módulo hasta 5 min antes de expirar.
  - `cambiarTemas(cuenta, token, temas: string[], accion: 'alta'|'baja', opts) -> Promise<{ok: boolean}>` — por cada tema `POST https://iid.googleapis.com/iid/v1:batchAdd` (o `:batchRemove`) con `{to: '/topics/<tema>', registration_tokens: [token]}`, headers `Authorization: Bearer <oauth>`, `access_token_auth: true`. `ok=false` si alguna respuesta no es 2xx o trae `results[i].error`.
  - `enviarATema(cuenta, aviso: {tema, titulo, cuerpo}, opts) -> Promise<{ok: boolean, status: number}>` — `POST https://fcm.googleapis.com/v1/projects/<project_id>/messages:send` con `{message: {topic, notification: {title, body}, webpush: {notification: {icon: 'https://cuandopagan.3qbic.com/icons/Icon-192.png'}, fcm_options: {link: 'https://cuandopagan.3qbic.com/'}}}}`.
  - Ninguna función escribe en `console` el token FCM ni la llave.

- [ ] **Step 1: Write the failing tests** — en el test se genera una llave RSA 2048 con `crypto.subtle.generateKey` y se exporta a PEM PKCS#8 para armar una cuenta falsa; `fetchImpl` es un mock que registra llamadas.
  - `cuentaDeServicio({})` → `null`; con JSON roto → `null`; con JSON válido → objeto con los 3 campos.
  - `tokenOAuth`: la llamada va a `oauth2.googleapis.com/token`; el `assertion` tiene 3 partes, header `{"alg":"RS256","typ":"JWT"}`, payload con `scope` y `aud` exactos, y **la firma verifica** con la llave pública; segunda llamada dentro de la hora no vuelve a pedir token.
  - `cambiarTemas(..., ['grupo3-d1','grupo3-d3'], 'alta')` → 2 POST a `iid/v1:batchAdd` con `to:'/topics/grupo3-d1'` y header `access_token_auth: 'true'`; con `'baja'` usa `:batchRemove`; respuesta `{results:[{error:'NOT_FOUND'}]}` → `ok:false`.
  - `enviarATema` arma el body exacto de arriba; status 500 → `ok:false`.
  - espía de `console.log/error/warn` durante todos los tests: ningún argumento contiene el token de prueba `'tok_PRUEBA_123'`.
- [ ] **Step 2: Run** — `npm test` → FAIL.
- [ ] **Step 3: Implement `worker/src/fcm.js`** (base64url sin padding; PEM → DER quitando cabeceras y saltos).
- [ ] **Step 4: Run** — `npm test` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(worker): cliente FCM con OAuth RS256 por WebCrypto"`

---

### Task 3: Worker — rutas `/v1/push/*`, cron diario y métricas

**Files:**
- Create: `worker/src/push.js`
- Modify: `worker/src/index.js` (CORS, método, ruteo, `scheduled`), `worker/wrangler.toml` (`crons = ["0 12 * * *"]`)
- Test: `worker/test/push.test.js`

**Interfaces:**
- Consumes: Task 1 (`tema`, `ANTICIPACIONES`, `avisosDelDia`, `fechaPanama`), Task 2 (`cuentaDeServicio`, `cambiarTemas`, `enviarATema`), `registrar` de `metricas.js`.
- Produces:
  - `manejarAlta(request, env, deps) / manejarBaja(request, env, deps) -> Promise<Response>`. Body JSON `{token: string, categoria: string (wire), anticipaciones: number[], realta?: boolean}`. Validación: token `^[A-Za-z0-9_:\-]{20,4096}$`; categoría en `SLUG`; anticipaciones no vacías, sin repetidos, todas en `{0,1,3}`. Respuestas: `200 {ok:true, temas:[...]}`; `400 {error:'solicitud inválida'}` (nunca incluye el token); `503 {error:'push no configurado'}` si no hay cuenta; `502 {error:'no se pudo actualizar la suscripción'}` si Google falla.
  - Métricas por cada anticipación: `registrar(env, realta ? 'push_realta' : 'push_alta' | 'push_baja', [slug, 'd' + n])`.
  - `correrAvisos(env, hoy: string, {soloTema?: string, dry?: boolean}, deps) -> Promise<{hoy, avisos:[{tema, titulo, cuerpo, ok?}]}>`; registra `push_envio` por tema con `[tema]`, `[enviados, errores]`.
  - Ruta manual `POST /v1/push/cron?hoy=YYYY-MM-DD&solo=<tema>&dry=1`: exige header `Authorization: Bearer <env.ADMIN_TOKEN>` (comparación de longitud fija); sin `ADMIN_TOKEN` configurado o con token incorrecto responde **404** (no revela que existe).
  - `index.js`: CORS `Access-Control-Allow-Methods: GET, POST, OPTIONS`; POST solo en `/v1/push/alta`, `/v1/push/baja`, `/v1/push/cron` (otro POST → 405). `scheduled`: `correrAvisos(env, fechaPanama(new Date(event.scheduledTime)))` y, si el día de la semana en Panamá es lunes, la verificación del MEF existente; cada parte en su `try/catch` para que una no tumbe la otra.
- `deps` = `{cambiarTemas, enviarATema, cuentaDeServicio, calendario, xiii, semestres}` inyectables; por defecto los reales.

- [ ] **Step 1: Write the failing tests** (deps falsas, `env.USO` falso que registra data points):
  - alta válida `{token:'tok_PRUEBA_123…'(≥20), categoria:'GRUPO 3', anticipaciones:[1,3]}` → 200, `temas:['grupo3-d1','grupo3-d3']`, `cambiarTemas` llamado con `'alta'`; 2 data points `push_alta` con blobs `['push_alta','grupo3','d1']` y `['push_alta','grupo3','d3']`.
  - `realta:true` → eventos `push_realta`.
  - baja válida → `'baja'` y eventos `push_baja`.
  - inválidos → 400 y `cambiarTemas` **no** llamado: JSON roto; `categoria:'GRUPO 4'`; `anticipaciones:[2]`; `[]`; `[1,1]`; token de 5000 chars; token `'<script>alert(1)</script>xxxxxxxxxx'`. El texto de la respuesta no contiene el token enviado.
  - sin `FCM_SERVICE_ACCOUNT` → 503; `cambiarTemas` devuelve `{ok:false}` → 502.
  - `correrAvisos(env, '2026-10-29', {}, deps)` con un calendario de una fila `GRUPO 3` `2026-10-30` → `enviarATema` llamado una vez con tema `grupo3-d1`; data point `push_envio` `['push_envio','grupo3-d1']`, doubles `[1,0]`. Con `dry:true` → no envía. Con `soloTema:'grupo1-d1'` → no envía nada.
  - `/v1/push/cron` sin header o con token incorrecto → 404; con el correcto y `dry=1` → 200 con la lista.
  - `OPTIONS /v1/push/alta` → 204 con `POST` en `Allow-Methods`; `POST /v1/all` → 405; `GET /v1/version` sigue 200 (regresión).
  - `scheduled` con `scheduledTime` de un lunes 12:00 UTC llama a la verificación del MEF y a `correrAvisos`; un martes solo a `correrAvisos`; si `correrAvisos` lanza, el MEF corre igual.
- [ ] **Step 2: Run** — `npm test` → FAIL.
- [ ] **Step 3: Implement** `push.js` y el wiring en `index.js`; cambiar el cron en `wrangler.toml`.
- [ ] **Step 4: Run** — `npm test` → PASS; `npx wrangler deploy --dry-run` compila sin error (no despliega).
- [ ] **Step 5: Commit** — `git commit -m "feat(worker): /v1/push alta/baja, cron diario de avisos y métricas de push"`

---

### Task 4: Proyecto Firebase (controller + usuario; sin subagente)

Guía paso a paso para Alexis, en la cuenta `alexis.garcia@gmail.com`. El controller verifica cada valor antes de seguir.

- [ ] **Step 1:** Alexis crea en console.firebase.google.com el proyecto **`cuando-pagan`**, **sin** Google Analytics (desmarcar al crearlo), plan Spark.
- [ ] **Step 2:** Registra una app **Web** "¿Cuándo Pagan? web" (sin Hosting). Copia el bloque `firebaseConfig` al chat: es público.
- [ ] **Step 3:** *Project settings → Cloud Messaging → Web Push certificates → Generate key pair.* Copia la **clave pública** VAPID al chat (pública).
- [ ] **Step 4:** *Project settings → Service accounts → Generate new private key.* El archivo se guarda en `~/Downloads`; **no** se pega en el chat. El controller lo carga con `npx wrangler secret put FCM_SERVICE_ACCOUNT < ~/Downloads/<archivo>.json` (con `CLOUDFLARE_ACCOUNT_ID` por env) y Alexis borra el archivo después.
- [ ] **Step 5:** El controller genera el token de administración sin mostrarlo: `openssl rand -hex 32 > ~/.config/cuandopagan/admin_token` (`chmod 600`, carpeta fuera del repo) y `npx wrangler secret put ADMIN_TOKEN < ~/.config/cuandopagan/admin_token`.
- [ ] **Step 6:** Commit de lo público: `lib/firebase_options.dart` (const `FirebaseOptions` web + `const kVapidKey`), `web/firebase-messaging-sw.js` con `importScripts` de `firebase-app-compat.js` y `firebase-messaging-compat.js` en la **versión exacta** que declara el `firebase_core_web` resuelto en `pubspec.lock` (constante `supportedFirebaseJsSdkVersion`), `firebase.initializeApp(<config>)` y `firebase.messaging()`. Verificar con `git diff --cached | grep -iE "private_key|client_email|BEGIN"` → vacío.

  > Nota: esta tarea agrega `firebase_core` y `firebase_messaging` al `pubspec.yaml` y corre `dart run tool/check_forbidden_deps.dart` (debe seguir en verde; ninguna dep de analytics).

---

### Task 5: App — dominio, datos y controlador del push

**Files:**
- Create: `lib/domain/logic/tema_push.dart`, `lib/data/push/push_api.dart`, `lib/data/push/push_plataforma.dart`, `lib/data/push/push_plataforma_web.dart`, `lib/application/push_controller.dart`
- Test: `test/domain/logic/tema_push_test.dart`, `test/data/push/push_api_test.dart`, `test/application/push_controller_test.dart`

**Interfaces:**
- Consumes: `Categoria` (`lib/domain/entities/categoria.dart`), contrato HTTP de Task 3.
- Produces:
  - `const kAnticipaciones = [0, 1, 3]; const kAnticipacionDefault = 1;` y `String temaPush(Categoria c, int n)` (mismos slugs que el Worker; lanza `ArgumentError` si `n` no está en la lista). Dart puro.
  - `class PushApi { PushApi({required http.Client client, required String baseUrl, Duration timeout = const Duration(seconds: 8)}); Future<bool> alta({required String token, required Categoria categoria, required List<int> anticipaciones, bool realta = false}); Future<bool> baja({required String token, required Categoria categoria, required List<int> anticipaciones}); }` — `true` solo con 200; nunca lanza.
  - `enum PermisoPush { concedido, denegado, sinPreguntar, noSoportado }`
  - `abstract class PushPlataforma { bool get soportado; bool get requiereInstalarApp; Future<PermisoPush> permiso(); Future<PermisoPush> pedirPermiso(); Future<String?> token(); Stream<String> get tokenRenovado; Stream<({String titulo, String cuerpo})> get mensajeEnPrimerPlano; }` y `class PushPlataformaNula implements PushPlataforma` (`soportado=false`, todo vacío).
  - `PushPlataformaWeb` (en `push_plataforma_web.dart`) con `firebase_messaging`: `token()` usa `getToken(vapidKey: kVapidKey)`; `requiereInstalarApp` = iOS/iPadOS sin modo standalone (`window.matchMedia('(display-mode: standalone)')` o `navigator.standalone`) usando `package:web`; `soportado` = `Notification` y `serviceWorker` existen. Sin tests unitarios (se verifica en navegador, Task 8).
  - `class EstadoPush { final bool activo; final List<int> anticipaciones; final Categoria? categoria; final PermisoPush permiso; final bool ocupado; final String? error; }`
  - `class PushController extends ChangeNotifier { PushController({required PushPlataforma plataforma, required PushApi api, required SharedPreferences prefs}); EstadoPush get estado; Future<void> iniciar(); Future<void> activar(Categoria c); Future<void> apagar(); Future<void> cambiarAnticipaciones(List<int> nuevas); Future<void> reconciliar(Categoria? favorita); }`
  - Prefs: `pushActivo` (bool), `pushAnticipaciones` (List<String>), `pushCategoria` (wire), `pushToken` (string, solo local).

- [ ] **Step 1: Write the failing tests** (fake `PushPlataforma` y `MockClient`):
  - `temaPush(Categoria.grupo3, 1) == 'grupo3-d1'`; `gastosRepresentacion, 0` → `'gastosrep-d0'`; `n=2` → `ArgumentError`.
  - `PushApi.alta` hace `POST <base>/v1/push/alta` con JSON `{token, categoria:'GRUPO 3', anticipaciones:[1], realta:false}`; 502 → `false`; timeout → `false`; excepción de red → `false`.
  - `activar(grupo3)` con permiso concedido → alta con `[1]`, prefs `pushActivo=true`, `pushCategoria='GRUPO 3'`, `pushToken` guardado; estado `activo`.
  - `activar` con `pedirPermiso` → `denegado`: no llama a la API, estado `permiso=denegado`, `activo=false`; una segunda llamada a `iniciar()` **no** vuelve a pedir permiso.
  - `activar` cuando la API devuelve `false`: `activo=false`, `error` no nulo, prefs sin `pushActivo`.
  - `cambiarAnticipaciones([0,3])` desde `[1]`: primero `baja([1])`, luego `alta([0,3])` (orden verificado); lista vacía equivale a `apagar()`.
  - `reconciliar(grupo1)` con suscripción a `GRUPO 3`: `baja(GRUPO 3, …)` luego `alta(GRUPO 1, …)`; `reconciliar(null)` → `apagar()`; misma categoría → sin llamadas.
  - token rotado: `iniciar()` con `pushToken='viejo'` y `token()` → `'nuevo'` → `alta(..., realta: true)` con `'nuevo'`, sin baja; prefs guardan `'nuevo'`. Igual con un evento de `tokenRenovado`.
  - `PushPlataformaNula`: `iniciar()` deja `permiso=noSoportado` y no lanza.
- [ ] **Step 2: Run** — `flutter test test/domain/logic/tema_push_test.dart test/data/push test/application/push_controller_test.dart` → FAIL.
- [ ] **Step 3: Implement** los 5 archivos. El dominio no importa Flutter ni Firebase.
- [ ] **Step 4: Run** — los mismos tests → PASS; `flutter test` completo → PASS; `dart run tool/check_forbidden_deps.dart` → OK.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): controlador de recordatorios push (temas, alta/baja, rotación de token)"`

---

### Task 6: App — tarjeta del Home y wiring

**Files:**
- Create: `lib/ui/recordatorio_card.dart`
- Modify: `lib/main.dart` (init de Firebase solo en web y dentro de `try` con timeout; crear `PushController` con `PushPlataformaWeb` o `PushPlataformaNula`; tarjeta en `HomeTab` debajo de la de institución, solo si hay favorito; `reconciliar(_sel?.categoria)` después de `_sincronizar` y al cambiar el favorito; flag `push` real en la apertura; snackbar para `mensajeEnPrimerPlano`), `lib/data/sync/dataset_sync.dart` (el `push:false` fijo pasa a un setter `sync.push`, igual que `appVersion`)
- Test: `test/ui/recordatorio_card_test.dart`, `test/data/sync/dataset_sync_test.dart` (caso nuevo)

**Interfaces:**
- Consumes: `PushController`, `EstadoPush`, `PermisoPush`, `kAnticipaciones` (Task 5).
- Produces: `class RecordatorioCard extends StatelessWidget { const RecordatorioCard({required EstadoPush estado, required bool requiereInstalarApp, required VoidCallback onActivar, required VoidCallback onApagar, required ValueChanged<List<int>> onAnticipaciones}); }`

Textos exactos:
- apagado: botón `🔔 Recordarme cuando me paguen`
- activo: `Listo, te avisaremos {lista}` con `{lista}` = `el mismo día` / `1 día antes` / `3 días antes` unidos con `, ` y ` y `; chips `El mismo día`, `1 día antes`, `3 días antes`; enlace `Apagar recordatorios`
- denegado: `Bloqueaste las notificaciones. Para activarlas, permítelas en la configuración del sitio de tu navegador (ícono del candado junto a la dirección).`
- iPhone sin instalar: `En iPhone, primero agrega la app a tu pantalla de inicio: toca Compartir y luego «Agregar a inicio». Después ábrela desde ese ícono.`
- error: `No pudimos activar los recordatorios. Intenta de nuevo.`
- `noSoportado`: la tarjeta no se muestra.
- nota fija debajo, en gris: `Recordatorio no oficial · fecha referencial (fuente: MEF)`

- [ ] **Step 1: Write the failing tests**
  - widget: estado apagado muestra el botón y tocarlo llama `onActivar`; activo `[1,3]` muestra `Listo, te avisaremos 1 día antes y 3 días antes` y tocar el chip `El mismo día` llama `onAnticipaciones([0,1,3])`; denegado muestra el texto de configuración y **no** el botón; `requiereInstalarApp=true` muestra el texto de iPhone y no el botón; `noSoportado` → `SizedBox.shrink`; desmarcar el único chip activo llama `onApagar`.
  - sync: `s.push = true` antes de `sincronizar()` → query `push=1`.
  - widget de la app: con `PushPlataformaNula` la app carga el Home sin la tarjeta y sin excepciones (Review Focus 2).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**; Firebase se inicializa con `Firebase.initializeApp(options: DefaultFirebaseOptions.web)` solo si `kIsWeb`, con `timeout(3 s)`; cualquier error → `PushPlataformaNula` y `debugPrint('[push] no disponible')`.
- [ ] **Step 4: Run** — `flutter test` → PASS; `flutter build web --release` compila.
- [ ] **Step 5: Commit** — `git commit -m "feat(app): tarjeta «Recordarme cuando me paguen» y wiring del push"`

---

### Task 7: Privacidad y docs

**Files:**
- Modify: `site/privacidad.html`, `lib/main.dart` (`PrivacidadScreen`, `_acercaHijos`), `ARQUITECTURA.md`, `CLAUDE.md`
- Test: `test/ui/privacidad_texto_test.dart` (nuevo)

Cambios de contenido (mismo texto en HTML e in-app):
- **Punto 5 «Notificaciones»** (reemplaza el texto actual): `Si activas los recordatorios, tu navegador genera un identificador de notificaciones (token) de Google Firebase Cloud Messaging. La app lo envía a nuestro servicio junto con tu categoría (por ejemplo, Grupo 3) y los días de anticipación que elegiste, solo para suscribirlo a ese aviso en Firebase. Nuestro servicio no guarda el token ni lo registra. Google (Firebase) lo conserva mientras la suscripción esté activa, para poder entregarte el aviso. Puedes apagarlos en cualquier momento desde la app o bloqueando las notificaciones del sitio en tu navegador. Si no los activas, nada de esto ocurre.`
- Resumen (lead / línea de "Resumen:"): `no recolectamos datos personales. Tus preferencias se quedan en tu dispositivo; solo contamos aperturas de forma anónima y, si activas los recordatorios, tu categoría y un token de notificaciones pasan por Google para avisarte.`
- §3: `Esta información nunca sale de tu dispositivo` → `Esta información se queda en tu dispositivo, salvo lo que se describe en el punto 5 si activas los recordatorios`.
- Terceros: agregar Google Firebase Cloud Messaging (solo si activas recordatorios).
- Acerca «Privacidad»: `No pedimos cuenta ni datos personales. Contamos aperturas de forma anónima (sin IP ni identificadores). Si activas los recordatorios, tu categoría y un token de notificaciones pasan por Google para avisarte.`
- In-app: agregar la sección de Notificaciones (hoy no existe) y renumerar las siguientes.
- `ARQUITECTURA.md`: endpoints `/v1/push/alta|baja|cron`, cron diario, secrets `FCM_SERVICE_ACCOUNT` y `ADMIN_TOKEN`. `CLAUDE.md`: cron diario y cómo disparar el cron manual (`curl -X POST -H "Authorization: Bearer $(cat ~/.config/cuandopagan/admin_token)" "https://cuandopagan.3qbic.com/v1/push/cron?hoy=YYYY-MM-DD&dry=1"`); quitar "No hay suite de tests automatizada".

- [ ] **Step 1: Write the failing test** — el texto in-app contiene `Firebase Cloud Messaging` y `no guarda el token`, y **no** contiene `Nunca sale de tu dispositivo`; un test de Dart lee `site/privacidad.html` y verifica lo mismo y que ya no contiene `se generarán y programarán localmente`.
- [ ] **Step 2: Run** → FAIL. **Step 3:** editar. **Step 4:** `flutter test` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "docs(privacidad): recordatorios push con FCM; docs del cron y endpoints"`

---

### Task 8: Release 0.6.0 (controller; cada paso de producción con aprobación)

- [ ] **Step 1:** `pubspec.yaml` → `version: 0.6.0+11`. Revisión final de rama (opus). `flutter test`, `npm test`, `python3 -m unittest`, deps prohibidas.
- [ ] **Step 2:** Pre-mortem al usuario y aprobación.
- [ ] **Step 3:** Deploy del Worker. Verificar: `/v1/version` 200; `OPTIONS /v1/push/alta` 204; `POST /v1/push/alta` con body inválido → 400; `/v1/push/cron` sin token → 404; con token y `dry=1&hoy=<un día con avisos>` → lista esperada; **un alta real con un token de prueba falso devuelve 502 sin eco** (prueba que Google responde y que la API de temas IID sigue disponible). Si la API de temas no está disponible: detenerse y replantear con el usuario.
- [ ] **Step 4:** `flutter clean && flutter pub get && flutter build web --release`; verificar `grep -c firebase build/web/main.dart.js` ≥ 1 y que `build/web/firebase-messaging-sw.js` existe; copiar `privacidad`; `wrangler pages deploy`.
- [ ] **Step 5:** Aceptación en Chrome de escritorio y en el Galaxy S24+ (Chrome Android): activar con favorito MIDES → Grupo 3, 1 día antes; cerrar la pestaña; disparar `POST /v1/push/cron?hoy=<día anterior a un pago de Grupo 3>&solo=grupo3-d1`; el push llega con `Mañana te pagan 💸`, al tocarlo abre el Home. Verificar que la auto-recarga de `web/index.html` no entra en loop (dos SW conviven) y que `metricas.py` muestra `push_alta` y `push_envio`. iPhone como PWA si hay uno a mano; si no, queda como riesgo declarado.
- [ ] **Step 6:** Logs del Worker sin tokens (revisar en el dashboard las invocaciones de la prueba).
- [ ] **Step 7:** Merge `release/0.6.0` → `main`, tag `v0.6.0`, back-merge a `develop`, grep de secretos del diff, push. Actualizar memoria.
