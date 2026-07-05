# Spec — Desplegar el Worker API `/v1/*` y conectar la app (online + offline)

**Estado:** SPEC (no implementado). Creado 2026-07-05. Pendiente de ejecución.
**Contexto maestro:** `ARQUITECTURA.md` (Worker, ETag/304, cron) · `CLAUDE.md` (§ operativo) · `.superpowers/sdd/progress.md` (4 costuras de integración de Plan 1).

---

## 1. Objetivo

Que la app **se actualice sola** cuando el MEF publique un semestre nuevo, sin
republicar el APK ni redeploy de la web. Hoy la app carga **100% desde la semilla
offline** (`assets/seed/all.json`) y nunca consulta la red. Falta: (a) **desplegar
el Worker** que ya existe (`worker/src/index.js`) para servir `/v1/*`, y (b)
**cablear la sincronización** en la app usando la capa de datos que ya se construyó
en Plan 1 (`WorkerApi`, `SyncController`, `CalendarioRepository`, drift).

Debe seguir siendo **offline-first**: si no hay red o el Worker no responde, la app
funciona igual con lo último que tenga en local (semilla o última sync).

## 2. Estado actual (lo que YA existe)

- `worker/src/index.js` — sirve `/v1/version`, `/v1/all`, `/v1/calendario`,
  `/v1/grupos`, `/v1/xiii`, `/v1/status`; CORS abierto; ETag `"v{data_version}"` → 304.
  Importa los JSON del bundle (sin KV/R2 obligatorio). **Probado local, sin desplegar.**
- `worker/wrangler.toml` — nombre `calendario-pago-pa`, cron semanal para detección.
- App: capa de datos de Plan 1 lista pero **no conectada a la UI** (`lib/main.dart`
  solo lee la semilla). `kWorkerBaseUrl = 'https://cuandopagan.3qbic.com'` en
  `lib/core/constants/umbrales.dart`.

## 3. Decisión clave: routing (Worker vs Pages en el mismo dominio)

`cuandopagan.3qbic.com` ya lo sirve **Cloudflare Pages** (la app). El Worker necesita
`/v1/*` en **ese mismo dominio** (porque `kWorkerBaseUrl` apunta ahí). Opciones:

| Opción | Cómo | Pros / Contras |
|---|---|---|
| **A. Worker Route `cuandopagan.3qbic.com/v1/*` (recomendada)** | Deploy del Worker + una route en la zona `3qbic.com` que intercepte `/v1/*` (las Worker Routes tienen precedencia sobre Pages para las rutas que hacen match). | ✅ No cambia `kWorkerBaseUrl` · ✅ Un solo dominio (CORS trivial) · ⚠ Verificar precedencia route↔Pages. |
| B. Subdominio `api.cuandopagan.3qbic.com` | Custom domain del Worker + DNS. | ✅ Aislado y claro · ⚠ Cambiar `kWorkerBaseUrl` + CORS entre orígenes. |
| C. Pages Functions | Mover `/v1/*` a `functions/v1/` del proyecto Pages. | ✅ Un solo deploy · ⚠ Reescribir el Worker como Functions; el cron de detección no aplica igual. |

**Recomendada: A.** Mantener `kWorkerBaseUrl` como está.

## 4. Alcance del trabajo (cuando se ejecute)

1. **Desplegar el Worker** (`cd worker && npx wrangler deploy`) y crear la **route**
   `cuandopagan.3qbic.com/v1/*` (opción A). Verificar `/v1/version` devuelve JSON
   (hoy devuelve el HTML de la app) y que `/v1/all` trae los 120 registros.
2. **Cablear la sync en la app** (reutilizando Plan 1, sin reimplementar):
   - Al abrir: `GET /v1/version` (~100 B). Si `data_version > ultimaDataVersion`
     local → `GET /v1/all` (con ETag → 304 si no cambió) → escribir a drift vía el
     swap atómico existente → refrescar la UI.
   - Resolver primero las **4 costuras de integración** registradas en
     `.superpowers/sdd/progress.md` (unificar decode de `/v1/all`; hilar la versión
     remota real a `proximoPago`; persistir el `Manifest` completo; cablear el gate
     de CI de deps).
   - `lib/main.dart` debe leer del **repositorio** (no directo de la semilla): semilla
     como estado inicial → hidratar de drift → sincronizar en background.
3. **Sin regresiones offline:** sin red, todo funciona con lo último en local.
   Ningún cambio a los invariantes (zona `America/Panamá` fija, `fecha_pago`
   verbatim, cero SDKs de tracking, XIII bajo demanda).

## 5. Criterios de aceptación

- [ ] `curl https://cuandopagan.3qbic.com/v1/version` → JSON con `data_version` (no HTML).
- [ ] `curl -H 'If-None-Match: "v1"' …/v1/version` → **304**.
- [ ] La app, con red, detecta una `data_version` mayor y actualiza sin redeploy del APK/web.
- [ ] La app, **sin** red, abre y muestra datos (semilla o última sync) sin crashear.
- [ ] `flutter test` sigue verde; el check de deps prohibidas sigue verde.
- [ ] Costo **$0** (free tier). El cron de detección semanal sigue operando.

## 6. Fuera de alcance

- Notificaciones push / recordatorios (fase posterior).
- KV/R2 (opcional; el Worker funciona sin ellos).
- Publicar en Google Play / App Store.
- Automatizar el parseo del PDF del MEF (sigue siendo transcripción manual a
  `build_dataset.py`).

## 7. Riesgos / notas

- **Precedencia route↔Pages:** confirmar que la Worker Route gana sobre Pages para
  `/v1/*` (si no, usar opción B).
- **Cache de borde vs frescura:** el ETag `"v{data_version}"` ya da 304; cuidar que
  el cache no sirva una versión vieja tras publicar (revisar `Cache-Control`).
- **Publicación de datos** (transcribir semestre nuevo) es un runbook **aparte**
  (ARQUITECTURA §8), no forma parte de este spec.
