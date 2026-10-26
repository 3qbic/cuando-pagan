# Diseño — Recordatorios push de pago + métricas de uso (¿Cuándo Pagan?)

**Estado:** DISEÑO revisado (builder check hecho; preguntas abiertas resueltas por Alexis). 2026-10-25.
**Depende de:** `docs/superpowers/specs/2026-07-05-worker-api-deploy-spec.md` (desplegar el Worker y cablear la sync). Ese spec es la **Fase 1** de este trabajo y se ejecuta tal cual; este documento agrega las Fases 2 y 3.
**Contexto vinculante:** `docs/superpowers/specs/2026-06-26-app-cuando-pagan-design.md` §0.1 (invariantes), `CLAUDE.md`.

---

## 1. Intención (el porqué)

La app solo existe en **web** (`cuandopagan.3qbic.com`, Cloudflare Pages, cuenta 3QBIC) y casi no tiene uso medido: unas 30 cargas de página en 4 meses según Cloudflare Web Analytics, que además **muestrea** los datos. El usuario (Alexis) quiere dos cosas:

1. **Que la app avise al usuario antes de que le paguen.** "Mañana te pagan". Lo quiere **"pro"**: una notificación push real con el nombre y el ícono de ¿Cuándo Pagan?, como la que ya hizo en Budoka con Firebase. **Descartó explícitamente** el camino de "agregar a mi calendario (.ics)" porque le pareció muy básico.
2. **Saber cuántos la usan, con precisión y consultable por CLI.**

El Worker que hoy falta desplegar pasa a ser **obligatorio**: es el reloj que dispara los avisos, y además resuelve que el MEF publica cada 6 meses (sin el Worker, cada semestre exige un redeploy).

## 2. Lo que decidió el usuario

- Recordatorio **parametrizable por el usuario**: el mismo día, 1 día antes o N días antes (su ejemplo fue 3).
- Ejemplo de mensaje del usuario: **"Mañana te pagan"**.
- **Push con Firebase (FCM)**, igual que Budoka. Incluye pedir permiso de notificaciones al usuario.
- **Solo web por ahora.** No hay app en Play ni en App Store.
- Métricas **más precisas que Cloudflare Web Analytics** y que Claude pueda **consultar por CLI**.
- GA4 ya se había descartado antes (2026-07-05) por chocar con la promesa de "sin rastreadores". Eso sigue en pie.

## 3. Metas, no-metas y anti-metas

**Metas**
- El usuario con favorito (institución → categoría/grupo) activa los recordatorios, elige la anticipación y recibe el push en su navegador **aunque tenga la pestaña cerrada**.
- Las métricas de uso diarias son exactas (sin muestreo a este volumen) y se consultan con un script.
- Costo **$0**: Cloudflare free y Firebase Spark.

**No-metas (v1)**
- App nativa Android o iOS. Cuando exista, reusará FCM; ahí el recordatorio podrá ser local.
- Hora del aviso elegida por el usuario.
- Correo, WhatsApp, Telegram.
- Contar usuarios únicos.
- Push de "salió el calendario nuevo del MEF". Queda como fase posterior; la infraestructura de esta fase la habilita.

**Anti-metas (fracasos aunque "funcione")**
- **Avisar en el día equivocado.** Off-by-one de zona horaria o un mensaje de "mañana" que llega el día del pago. Destruye la confianza en una app cuyo único valor es la fecha.
- **Recolectar datos personales o identificadores por usuario.** Rompe la política publicada y el invariante de "cero tracking". No se guardan IP, user-agent ni IDs por instalación.
- **Que el push parezca oficial del MEF o del Gobierno.** Aplica el posicionamiento de "app no oficial" (§0.1 del spec maestro).
- Spamear: pedir el permiso al cargar la página, o reinsistir después de un "no".

## 4. Restricciones

- Invariantes de §0.1: hora `America/Panama` fija (UTC-5, sin DST); `fecha_pago` **verbatim**, sin correrla por fines de semana o feriados; parsing tolerante; cero SDKs de tracking. `firebase_messaging` y `firebase_core` **sí** están permitidos; `tool/check_forbidden_deps.dart` solo prohíbe analytics, crashlytics, sentry, ads, etc. No se debe agregar `firebase_analytics` por arrastre.
- **Deploy manual a propósito** (el usuario declinó auto-deploy). Web: `flutter build web --release` + `wrangler pages deploy` (ver la memoria de hosting / README). Worker: `npx wrangler deploy`.
- **Gitflow:** `feature/*` → `develop` → `release/*` → `main` + tag.
- La **Política de Privacidad** (in-app en `lib/main.dart` "PrivacidadScreen" + `site/privacidad.html` + "Acerca") se actualiza **en el mismo release** que activa el push y las métricas, antes de publicar. Frases como "Nunca sale de tu dispositivo" (§3) y "Lo tuyo se queda en tu dispositivo" (Acerca) dejan de ser ciertas si el push está activado: el token y la categoría pasan por el Worker hacia Google (FCM). Hay que reescribirlas para que digan qué sale, a quién y para qué, y que se puede apagar.
- Scripts multiplataforma (Mac y Windows), en `scripts/`, UTF-8 explícito.
- Flutter 3.41.4. La app web ya tiene un script de auto-recarga en `controllerchange` dentro de `web/index.html`.
- Pre-mortem obligatorio antes de cada deploy a producción (CLAUDE.md global).

## 5. Diseño

### Fase 1 — Desplegar el Worker + sync (ya especificado)

Ejecutar `2026-07-05-worker-api-deploy-spec.md` completo: Worker Route `cuandopagan.3qbic.com/v1/*` (opción A), sync al abrir la app y las 4 costuras de `.superpowers/sdd/progress.md`. Además:
- Cambiar el `catch (_)` mudo de `SyncController` por un manejo que deje rastro (log de debug y un estado consultable como "datos de la semilla" o "datos sincronizados"). Así no vuelve a pasar que el API falte por meses sin que nadie lo note.
- Agregar los semestres históricos 2019–2025 a `pipeline/processed.json` para que `scraper_mef.py` deje de marcarlos como NUEVO.

### Fase 2 — Métricas con Workers Analytics Engine

- Binding de Analytics Engine en `worker/wrangler.toml` (dataset, por ejemplo, `cuandopagan_uso`).
- **Eventos** (solo dimensiones agregadas: **sin IP, user-agent, token ni ID**):
  - `apertura`: cuando la app llama a `GET /v1/version`. La app manda su plataforma (`web`), la versión de la app y la `data_version` local por query (`?p=web&v=0.4.0&d=1`) o por header. El Worker la anota. Hay que considerar que `/v1/version` tiene `max-age=300` y que el borde puede servir desde caché sin ejecutar el Worker. El conteo tiene que hacerse **antes** del caché, o el request tiene que llegar siempre al Worker. Cómo lograrlo queda al builder, pero se verifica que cada apertura cuente.
  - `push_alta` / `push_baja`, con categoría y anticipación. La re-alta por rotación de token se anota como un evento aparte (`push_realta`) para no inflar el conteo.
  - *Llamada de Claude:* `apertura` lleva además la dimensión agregada `push=1/0`, sin ID. La cifra principal de "usuarios con push" es **aperturas diarias con push=1**, no "altas − bajas". FCM no da el total de suscritos por tema, y las bajas se pierden cuando alguien borra los datos del navegador.
  - `push_envio`, uno por corrida del cron: cuántos mensajes salieron por tema y si hubo errores.
- **Script** `scripts/metricas.py` (multiplataforma). Consulta la SQL API de Analytics Engine con un token de API de solo lectura (variable de entorno, nunca en el repo) e imprime una tabla: aperturas por día (últimos 30), por versión de app, altas y bajas de push netas por categoría y anticipación, y envíos.
- Cloudflare Web Analytics (inyectado en la zona) **se queda** para Core Web Vitals. No se agrega un beacon manual.
- **A verificar al inicio:** que Analytics Engine esté disponible en el plan Workers Free de la cuenta 3QBIC. Si no lo está, el fallback es contar en **D1** (free) con filas agregadas por día, nunca por usuario.

### Fase 3 — Push de recordatorio (FCM, web)

**Firebase**
- Proyecto Firebase **nuevo** para ¿Cuándo Pagan? (separado de Budoka), en la cuenta de Google **`alexis.garcia@gmail.com`**, igual que Budoka (decisión de Alexis). Lo crea Alexis en la consola, con Claude guiando; la llave de la service account la carga Claude como secret. Plan Spark gratuito, con app web registrada y llave VAPID. *Llamada de Claude:* un proyecto separado aísla cuotas, permisos y la futura app Android.
- La cuenta service-account para enviar va como **secret del Worker** (`wrangler secret put`), nunca en el repo.

**Modelo sin base de usuarios: temas de FCM**
- Un tema por categoría × anticipación, por ejemplo `grupo3-d1`, `jubilados-d0`, `gastosrep-d3`. Con 5 categorías × 3 anticipaciones son 15 temas.
- La app web **no puede** suscribirse a temas desde el navegador. Por eso el Worker expone `POST /v1/push/alta` y `POST /v1/push/baja` con `{token, categoria, anticipaciones[]}`. El Worker suscribe o desuscribe el token del lado servidor con la API de administración de temas de FCM, y **no guarda el token**: no se registra en logs ni en KV. Se valida que la categoría y la anticipación estén en la lista permitida. El CORS del Worker hoy solo permite `GET`; hay que abrir `POST` en esas rutas.
- Si cambia el favorito o las anticipaciones, primero se da de baja lo anterior y luego se da de alta lo nuevo. Si el token rota, se repite el alta.
- **Cambio de grupo entre semestres** (*llamada de Claude*): en cada apertura, después de la sync, la app recalcula la categoría del favorito. Si difiere de la suscrita, hace la baja y el alta en silencio. Se acepta el riesgo residual de que alguien que no abre la app durante el cambio de semestre reciba los avisos del grupo viejo. Mitigación: el cron no envía nada si el semestre en curso no está en `manifest.semestres`.

**Anticipaciones v1:** `0` (el mismo día), `1` (un día antes) y `3` (tres días antes), y el usuario puede marcar varias. *Llamada de Claude:* son fijas y no un número libre, porque cada valor es un tema. El valor por defecto al activar es **1 día antes**.

**Cron de envío**
- Cron **diario a las 7:00 AM hora de Panamá** (`0 12 * * *` UTC). *Llamada de Claude:* la hora; Alexis no la eligió.
- El cron semanal de detección del MEF (`0 12 * * 1`) se **fusiona** en el diario: los lunes además revisa el MEF.
- Algoritmo: `hoy` = fecha calendario en `America/Panama`. Para cada fila de `calendario` y cada anticipación `N` en {0, 1, 3}: si `fecha_pago − N días == hoy`, se envía a `{categoria}-d{N}`. Hay que evitar duplicados si dos quincenas coinciden; con este modelo no debería pasar, pero se protege igual.
- **XIII Mes (decisión de Alexis, 2026-10-25: SÍ se avisa).** El cron también recorre `xiii_mes` (`fecha_aprox`) con las mismas anticipaciones, y envía a los **mismos temas** a los que el Home muestra el décimo como próximo pago. El builder replica la regla que ya usa `calcularProximoEvento` y no inventa una nueva. Los textos siempre dicen que la fecha es **aproximada**: d1 "Se espera tu décimo mañana 💰 · fecha aproximada (fuente: MEF)", d0 "Hoy se espera tu décimo", d3 "Faltan 3 días para tu décimo (fecha aproximada)". Si el mismo día coinciden quincena y décimo para un tema, se manda **un solo** push que mencione ambos.
- Envío por FCM HTTP v1 (`message.topic`) con un token OAuth obtenido firmando un JWT RS256 con WebCrypto en el Worker.
- **Lógica de fecha en función pura y testeable** (como `calcularProximoPago` en el dominio). Con tests de bordes: el día 0, cambio de mes, cambio de año (las quincenas de enero) y la hora UTC del cron frente a la fecha de Panamá. Es la anti-meta #1.

**Textos** (tono de la app, no oficial)
- d0: título "Hoy te pagan 💸", cuerpo "Grupo 3 · jueves 30 de octubre · fecha referencial (fuente: MEF)".
- d1: "Mañana te pagan 💸".
- d3: "Faltan 3 días para tu pago".
- La categoría se muestra con el nombre que ya usa la UI. La fecha va en español de Panamá. *Llamada de Claude:* el texto exacto y la coletilla "fecha referencial (fuente: MEF)", para cumplir el disclaimer de "no oficial".
- Al tocar la notificación se abre o enfoca `cuandopagan.3qbic.com` en el Home.

**UX en la app (web)**
- Tarjeta o botón en el Home, visible **solo si hay favorito**: "🔔 Recordarme cuando me paguen". El permiso se pide **solo al tocarlo**, nunca al cargar.
- Después de conceder: selector de anticipaciones (chips) y confirmación "Listo, te avisaremos 1 día antes". Se puede apagar desde el mismo lugar.
- Si niega el permiso: un mensaje corto de cómo reactivarlo desde el navegador. No se vuelve a pedir solo.
- **iPhone:** Safari solo acepta Web Push si la app está **agregada a la pantalla de inicio** (iOS 16.4+). En iOS sin PWA instalada se muestra cómo instalarla en vez del botón.
- El estado (activado, anticipaciones, categoría suscrita) se guarda en `SharedPreferences` local.

**Service worker**
- FCM web necesita `firebase-messaging-sw.js` en `web/`, que convive con el service worker de Flutter y con el script de auto-recarga de `web/index.html`. **Riesgo:** que dos SW se pisen el scope o que la auto-recarga entre en loop. Hay que verificarlo en un navegador real tras el deploy (Chrome en Android, Chrome de escritorio, iOS como PWA).

## 6. Lo que queda al builder

- Estructura de archivos y nombres en el Worker (módulos para el push y el cron), y si se usan `lib/application`/`lib/data` o una capa nueva en Flutter para el push (respetando el DIP: el dominio no importa Flutter ni Firebase).
- Cómo garantizar que la apertura se cuente aunque haya caché de borde.
- La forma exacta de las tablas del script de métricas.
- El orden interno de las tareas, siempre que se respete **Fase 1 → 2 → 3** y que cada fase se pueda publicar sola.

## 7. Criterios de aceptación

- [ ] `curl https://cuandopagan.3qbic.com/v1/version` devuelve JSON (no HTML), y la app sincroniza (criterios del spec de Fase 1).
- [ ] `python scripts/metricas.py` (Mac y Windows) muestra las aperturas del día después de abrir la app; los números cuadran con aperturas de prueba controladas.
- [ ] Activar un recordatorio en Chrome de Android o de escritorio, cerrar la pestaña y recibir el push en la fecha correcta. Se prueba con un disparo manual del cron con "hoy" simulado, sin esperar a una quincena real.
- [ ] Tests de la función de fechas del cron en verde, con los bordes de la §5.
- [ ] Ningún log del Worker contiene tokens ni IP; Analytics Engine solo tiene dimensiones agregadas.
- [ ] Política de privacidad (in-app + `site/privacidad.html`) actualizada y publicada en el mismo release.
- [ ] `flutter test` y `dart run tool/check_forbidden_deps.dart` en verde; costo $0.
