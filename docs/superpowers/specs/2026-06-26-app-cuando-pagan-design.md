# Spec de diseño — App "¿Cuándo Pagan?" (Panamá)

> **Estado:** diseño aprobado para plan de implementación · **Fecha:** 2026-06-26 · **Autor:** Alexis García (con análisis multi-agente)
> **Repo base:** `calendario-pago-pa` (pipeline + Cloudflare Worker existentes). Esta app Flutter **consume** ese Worker; no lo reescribe.

## Cómo leer este documento

1. **§0 — Resumen, premisas y decisiones** (esta sección).
2. **§0.1 — Decisiones y correcciones VINCULANTES.** Derivadas de dos revisiones adversarias. **Prevalecen sobre cualquier texto del cuerpo que las contradiga.** Si el cuerpo dice "fuente oficial" y aquí se corrige a "canal oficial del MEF", manda esta sección.
3. **Cuerpo** (§A Producto y Diseño · §B Arquitectura e Implementación · §C Cumplimiento, Legal y Textos): la síntesis detallada. Es la referencia de tokens, modelos, pantallas y textos.
4. **Anexo — Registro de revisión adversaria:** hallazgos crudos de ambos revisores (trazabilidad).

---

## §0. Resumen y premisas

**Qué es:** herramienta de consulta **independiente, gratuita y de código abierto** que responde "¿cuándo le pagan a tal institución del sector público de Panamá?". Toma las fechas que el **MEF publica en sus canales públicos**, las transcribe verbatim y las presenta con próximo pago, contador regresivo, calendario, recordatorios locales y widget. **No es oficial, no representa al Gobierno, no tramita pagos.**

**Premisas confirmadas (ley del proyecto):**

| # | Premisa |
|---|---|
| 1 | **Posicionamiento:** independiente · no oficial · sin afiliación gubernamental. Sin escudo/bandera/Marca País como identidad. El MEF se cita SOLO como "fuente pública". Riesgo de confusión declarado **ALTO** (las fechas son las reales). |
| 2 | **Plataformas:** Flutter — **Android = primaria** (plataforma de publicación), **iOS 16+** (moderno) y **Web**. Widget Android (App Widget) requerido; en iOS, WidgetKit + Live Activity (ver §0.1-D17). No se soportan iOS < 16 (cuota de mercado marginal). |
| 3 | **Modelo de fecha v1 = "solo fuente pública":** se muestran fechas ya publicadas (estado *Publicada*); períodos no publicados = *Pendiente*. Estados *Modificada* y *Desactualizada* en el modelo. *Estimada* reservado/dormido para Fase 2 (sin motor de estimación en v1). |
| 4 | **Features v1:** próximo pago + contador, calendario anual, **XIII Mes (bajo demanda, ver decisión)**, notificaciones locales, avisos, panel de fuentes/criterios, estados de fecha, favorito, offline parcial, dark mode, widget, Acerca de/disclaimer. |
| 5 | **Dirección visual:** editorial audaz / dark-first / anti-AI-slop; sin Material 3 morado, sin colores de bandera. Accesible (WCAG AA; estados no dependen solo del color). |
| 6 | **Privacidad:** sin cuentas, sin login, sin datos personales; todo local. |
| 7 | **Idioma:** español neutral panameño. Horas 12h AM/PM. Zona `America/Panamá` (UTC-5, sin DST). |

**Decisiones del usuario (2026-06-26):**
- **Nombre:** **¿Cuándo Pagan?** (marca/wordmark). Técnico/dominio sin signos: **Cuándo Pagan / `cuandopagan.app`**. Logomark: el signo "¿" en lima `#C6F647`.
- **XIII Mes (Décimo Tercer Mes):** **bajo demanda.** NO se muestra siempre; aparece **solo cuando el usuario lo consulta/busca** ("¿cuándo pagan el décimo tercer mes?" / "XIII" / "decimotercer"). Entonces muestra las 3 fechas aproximadas de `xiii_mes.json` (dato de la fuente, **no hardcodeado**) con etiqueta **"Aproximada"** y atribución (ver §0.1-B8).
- **Alcance:** MVP + favorito + recordatorios locales (sin backend).
- **Prioridad de plataforma:** **Android primero** (es lo que se puede publicar) → **iOS 16+** (moderno; WidgetKit + Live Activity) → **Web**. Targets mínimos: Android `minSdk 24` (Android 7.0), iOS **16.0**. Sin soporte a versiones antiguas marginales.

---

## §0.1 Decisiones y correcciones VINCULANTES (prevalecen sobre el cuerpo)

> Resultado de dos revisiones adversarias (accesibilidad/completitud y legal/confusión/tiendas). Cada ítem es **requisito de release**, no "nice to have". El plan de implementación (writing-plans) encodea estas reglas.

### A. Legal, posicionamiento y wording

- **A1 · Nombre y "Panamá":** marca `¿Cuándo Pagan?`; técnico/dominio `Cuándo Pagan`/`cuandopagan.app`. "Panamá" en el título de tienda es **alcance geográfico** (aceptable); **jamás** se usa el logotipo de la Marca País registrada "Panamá".
- **A2 · Regla "oficial" (codificada):** la palabra *oficial* SOLO puede modificar al **canal / publicación / sitio del MEF** ("el sitio oficial del MEF", "los canales oficiales del MEF"); **nunca** a la app, sus datos, fechas o avisos. Reemplazos obligatorios en todo el copy:
  - "Ver en la fuente oficial (MEF)" → **"Ver en el sitio oficial del MEF"**.
  - "prevalece la fuente oficial del MEF" → **"prevalece la publicación oficial del MEF"**.
  - Disclaimer largo: "las fechas oficiales de pago publicadas por el MEF" → **"las fechas de pago que el MEF publica en sus canales oficiales"**.
  - Añadir a la lista negra: **"datos/fechas oficiales (de la app)"**.
- **A3 · Copy de onboarding/empty:** NO preguntar por el empleador. "¿Y tú, dónde trabajas?" → **"¿Qué calendario te interesa? Elige tu institución o grupo."**
- **A4 · Aserciones en 2ª persona:** "Te pagan hoy/mañana" se permite **solo dentro de la app** y siempre con chip de estado + afford "verificar en la fuente" co-ubicados. En **push/widget**: prohibido "Tu fecha cambió" sin atribución → **"El MEF publicó un cambio en una fecha de pago — verifica en el sitio del MEF · no oficial"**. Forma preferente menos personal donde no haya disclaimer rico: **"Pago previsto: {fecha} (según MEF)"**.
- **A5 · Trazabilidad en cada fecha aseverada:** héroe, widget y push co-ubican estado + enlace/afford a la fuente; nunca enterrado solo en "Acerca de".
- **A6 · Contador / zona horaria (copy):** "El contador depende de la hora de tu dispositivo" → **"Los días restantes se calculan en hora de Panamá (UTC-5); requiere que el reloj de tu dispositivo esté correcto."**

### B. Datos / dataset (desconexiones reales con la fuente)

- **B7 · Capa de siglas/alias (NUEVA, requisito del caso núcleo):** `grupos_entidades.json` NO trae siglas; escribir "MIDES" no encuentra nada. Agregar `siglas: List<String>` a `Entidad` y un **mapa curado en el repo** (MIDES, MEDUCA, MINSA, MOP, MEF, MINGOB, MICI, MIRE, MIDA, MINSEG, MiAMBIENTE, MITRADEL, MIVIOT, MINMUJER, etc.), auditable, **separado del dato de fecha** (no contamina el verbatim). Búsqueda **normalizada** (sin acentos, por sigla y por nombre).
- **B8 · XIII Mes BAJO DEMANDA en v1 (decisión del usuario):** "cableado" = **conectar** el dato de `xiii_mes.json` (que llega del Worker, **no se hardcodea** en Dart) a una consulta + UI; nunca constantes en código. El XIII **no es una tarjeta fija**: se surface **solo al consultarlo** — el buscador reconoce "décimo tercer mes", "decimotercer", "XIII", "13" y devuelve una entrada *Décimo Tercer Mes (XIII)* que abre sus 3 fechas (~feb, ~ago, ~dic) etiquetadas **"Aproximada"** (`Precision.aproximada`) con atribución. Implementación: entidad `XiiiMes` + `XiiiDao` (query sobre la tabla `xiii_mes`) + resultado de búsqueda/ficha dedicada. **Nunca** presentar la fecha aproximada como exacta ni como "póster lima Publicada". Si el favorito no es XIII, no ocupa espacio en Home/Calendario.
- **B9 · Display de entidades:** los nombres llegan abreviados y sin tildes ("Min. de Educacion"). Añadir `Entidad.display` (tildes correctas; opción de expandir "Min." → "Ministerio de"), separado de `nombreWire`. La UI y Semantics usan `display`.
- **B10 · Parsing forward-compatible:** `Categoria.fromWire`, `EstadoFecha` y `Precision` deben usar `orElse` → default seguro (`publicada`/`exacta`) + log local. **Nunca** crashear por un valor de wire nuevo.
- **B11 · Estado "Modificada" en v1:** alcanzable **solo por diff local** (instalaciones nuevas no lo ven hasta que el pipeline emita `cambios` en el manifest). Marcar como "parcialmente activo" en la doc. (Hueco Fase 2: campo server-side "dato en revisión/disputado" + canal de corrección más rápido que el bump de `data_version`.)

### C. Accesibilidad (la dirección dark-bold no puede romper WCAG)

- **C12 · Contraste light corregido:** `state.modified` light → `#8A5A00` (verificar ≥4.5:1 sobre `#F4F1EA`). Etiqueta "Aproximada" en light: token seguro ~`#8A5A00`; **marigold solo como fondo con tinta**, nunca como label en light. Ambos pares entran al golden/lint de contraste.
- **C13 · Foco sobre superficies lima/marigold:** token de foco **oscuro garantizado** (`#0B0B0C`) o doble-anillo (tinta + claro), exigido ≥3:1 contra la **superficie adyacente real** (no solo canvas). Caso golden obligatorio: "control enfocado sobre póster lima".
- **C14 · Contador y textScaler:** contenedor con **min-width que crece** con `textScaler` (no width fijo) o clamp explícito de `countdown.num`. Probar Home a `textScaler` 2.0 en golden.
- **C15 · Ribbon "no oficial":** texto ≥12–13px que **escale** con `textScaler`; **hit-target 48dp** aunque el visual sea slim; no roba foco ni tapa contenido.
- **C16 · Una sola cadena canónica de disclaimer persistente + un solo componente.** Alinear la matriz DoD: el badge/ribbon "no oficial" va en **todas** las pantallas (no solo la principal).

### D. Tiendas / publicación

- **D17 · iOS moderno + funcionalidad nativa (riesgo 4.2):** target **iOS 16+** (sin versiones antiguas marginales). En iOS v1 incluir **un widget WidgetKit** y/o una **Live Activity** de cuenta regresiva (Dynamic Island / pantalla de bloqueo; `home_widget` soporta WidgetKit) para evidenciar valor nativo y no depender solo del widget Android. *Prioridad:* Android es la plataforma de publicación primaria; iOS se construye moderno pero puede ir una tanda detrás si hace falta — **no** recortar el valor nativo iOS por debajo del umbral 4.2.
- **D18 · iOS ITMS-91053:** declarar **proactivamente** en `PrivacyInfo.xcprivacy` FileTimestamp (C617.1/DDA9.1) y DiskSpace (E174.1) si algún dep enlazado las usa (path_provider/drift/sqlite3/flutter_local_notifications). Correr **Privacy Report** de Xcode antes de enviar.
- **D19 · Overlay "No oficial" en TODOS los screenshots** de ambas tiendas (no solo el primero).
- **D20 · SEO/Web:** `<title>`, OG/Twitter title y H1 deben incluir **"no oficial / independiente"**; JSON-LD `WebApplication` (nunca `GovernmentService`); preferir `.app` sobre `.org`.
- **D21 · Canal de notificación Android** nombrado/descrito como **"App no oficial"**; disclaimer en la notificación **expandida**.
- **D22 · Categoría Tools/Utilities** documentada; keywords sin empujar a Apple/Play a re-bucketar como Finance/Government.

### E. Privacidad / Worker (sostener la declaración "no recolectamos datos")

- **E23 · Invariante de gobernanza del Worker:** la declaración "Data Not Collected" exige que el Worker **no loguee IP/headers identificantes** (sin Logpush; analítica de Cloudflare solo agregada). Documentar "procesamiento efímero por proveedor de infraestructura" en el formulario Data Safety. **Check de CI/PR** que falle si el Worker introduce logging de request. (El Worker es endpoint propio, no CDN ajeno: la efimeralidad se **garantiza**, no se asume.)

### F. Proceso y gobernanza (huecos → requisitos)

- **F24 · Verificación automatizada de la matriz DoD:** golden/integration test que **falle el build** si una superficie (pantalla, push, widget, screenshot) pierde el string/Semantics "no oficial". "Bloqueante" = gate automático, no aspiracional.
- **F25 · Gate de revisión legal** por abogado panameño (símbolos de la Nación; Ley 35/1996 marcas; Ley 45/2007 ACODECO; Ley 81/2019 datos) como **hito bloqueante** previo al envío, con responsable y fecha.
- **F26 · Plan de respuesta a takedown/queja** (MEF/ACODECO/competidor reporta impersonation): protocolo + contacto + kill-switch documentado.
- **F27 · Poblar placeholders** ([fecha], [correo], [URL repo], [mantenedor], dominio) y **publicar la política de privacidad en URL estable** ANTES de crear las fichas de tienda.

### G. Principios de código (vinculantes)

- **G28 · SOLID** como norma de la capa de código (se apoya en las 4 capas de §B):
  - **S (Responsabilidad única):** cada widget/clase/archivo, una sola responsabilidad (los 14 componentes y las capas ya lo reflejan). Un archivo que crece = hace de más → dividir.
  - **O (Abierto/cerrado):** `EstadoFecha` y `EstadoFechaChip` se extienden sin tocar consumidores; activar *Estimada* en Fase 2 no rompe la UI existente.
  - **L (Sustitución de Liskov):** un `CalendarioRepositoryFake` (tests) es intercambiable por el real sin cambiar la app.
  - **I (Segregación de interfaces):** interfaces pequeñas y específicas (`CalendarioRepository` y `PrefsRepository` separados; nada de un repo "dios").
  - **D (Inversión de dependencias):** UI/aplicación dependen de **interfaces de dominio**, no de `drift`/`http`; la inyección va por providers de Riverpod. Es el eje de §B: *domain no conoce Flutter ni red*.
- **G29 · DRY con criterio:** una sola fuente para cada cosa — string canónico del disclaimer (C16), `EstadoFechaChip` como **único** pintor de estado (§A-4), design tokens (§A-5), formato de fecha/hora centralizado (`core/format`), `hoyPanama()` único. **Pero** sin sobre-abstraer: rige **YAGNI** (no se construye motor de estimación ni capas especulativas) y la **regla de tres** (no se extrae un helper hasta el 3.er uso real). DRY no justifica acoplar cosas que solo *parecen* iguales.
- **G30 · Testabilidad como consecuencia:** la lógica pura de dominio (`proximoPago`, `etiquetaContador`, `detectarModificadas`, `hoyPanama`) se prueba en Dart puro sin Flutter — ahí viven los riesgos de off-by-one. **TDD** en esa capa (hito 1 de §B).

---


# §A — PRODUCTO Y DISEÑO

## Producto y Diseño — "¿Cuándo pagan?"

> Sección integrada del spec. Resuelve las 8 lentes en un solo sistema sin contradicciones. Donde dos lentes chocaron, se tomó una decisión y se marca con **Decisión de conflicto:** en una línea. Premisas 1–7 son ley; nada aquí las contradice.

---

## 1. Visión y propuesta de valor

**"¿Cuándo pagan?"** es una herramienta de consulta —independiente, gratuita y de código abierto— que responde de un vistazo la pregunta que el servidor público y el jubilado panameño ya se hacen: cuándo cae la próxima quincena. Toma las fechas de pago que el **Ministerio de Economía y Finanzas (MEF) ya publicó en sus canales públicos**, las transcribe verbatim y las presenta como un calendario claro, con cuenta regresiva, recordatorios locales y un widget en la pantalla de inicio. No tramita pagos, no pide cuenta ni datos personales, y funciona offline con la última copia descargada. Su valor es *claridad y anticipación sobre información que hoy está dispersa en PDFs*, no exclusividad del dato.

**Posicionamiento no oficial (estructural, no decorativo):**
- App **independiente · no oficial · no afiliada** al Gobierno de Panamá ni al MEF. El MEF se cita SOLO como **"fuente pública"** (origen del dato), nunca con verbos de relación ("provisto por", "powered by", "en alianza con").
- El nombre en voz interrogativa ciudadana es la primera defensa: un Gobierno nunca nombra una herramienta con una pregunta. El artefacto oficial real se llama *"Calendario de Pago del Sector Público"*; nos alejamos de ese registro a propósito.
- **Prohibido como identidad:** escudo, bandera, estrella patria, tricolor en disposición de bandera, marca país "Panamá", tipografía/sellos de papelería oficial, dominios que evoquen `.gob.pa`. La estética editorial-audaz existe precisamente para *no* parecer estatal.
- El disclaimer "No oficial" es **omnipresente y redundante** (onboarding, badge persistente, cada ficha de fecha, notificaciones, widget, Acerca de) y es **Definition of Done**: ninguna pantalla, push, widget o captura se aprueba sin su atribución.
- Verbo rector siempre **"consultar fechas"**, nunca "consulta/recibe **tu** pago", "trámite" ni "planilla". Junto a cada fecha vive su **estado** (Publicada/Modificada/Desactualizada/Pendiente): la app se presenta como *espejo fechado* de la fuente, no como verdad absoluta.

---

## 2. Mapa de pantallas y navegación (Arquitectura de Información)

**Modelo de navegación:** bottom navigation de 4 destinos primarios + un **ribbon "no oficial" persistente** (slim bar, tap → Acerca de) visible en todas las pantallas. Pantallas secundarias se abren como push o sheet. Onboarding bloqueante solo en el primer uso.

```
[ Onboarding 1er uso ]  (bloqueante)
   1. Disclaimer "independiente · no oficial"  → [Entendido]
   2. ¿Y tu institución?  → buscador  (opcional saltar)

Ribbon persistente: "App independiente · No oficial"  ───────────────┐
                                                                     │ (en TODAS)
BOTTOM NAV (primarios)
 ├─ ⓵ Inicio / Próximo pago         ← destino raíz
 │     ├─ (sheet) Selección de institución / buscador
 │     └─ (push)  Detalle de quincena
 ├─ ⓶ Calendario anual
 │     └─ (push)  Detalle de quincena
 ├─ ⓷ Avisos                         ← cambios, recordatorios, "se publicó X"
 └─ ⓸ Ajustes
       ├─ (push) Recordatorios
       ├─ (push) Fuentes y criterios   ← también accesible tocando "Fuente pública: MEF"
       └─ (push) Acerca de / disclaimer ← también accesible tocando el ribbon
```

**Reglas de IA:**
- "Mi institución" (favorito) es el estado por defecto de Inicio; sin favorito, Inicio invita a elegirla.
- El chip **"Fuente pública: MEF"** de cualquier fecha es un atajo directo a *Fuentes y criterios* (refuerza el modelo espejo).
- *Fuentes* y *Acerca de* son alcanzables desde al menos dos puntos cada una (redundancia del disclaimer).

---

## 3. Pantallas en detalle

Para cada pantalla: **propósito**, **contenido clave** y **estados** (cargando / vacío / sin-internet / desactualizado). Estados transversales se aplican igual salvo nota.

### 3.0 Onboarding (primer uso, bloqueante)
- **Propósito:** sembrar el disclaimer ANTES de que el usuario forme la creencia "es del Gobierno" (riesgo ALTO) y capturar "mi institución".
- **Contenido clave:** pantalla dedicada con disclaimer corto + botón **[Entendido]**; luego buscador "¿Y tú, dónde trabajas?" (saltable). Sin pedir permisos aún (notificaciones se piden contextualmente después).
- **Estados:** sin red → igual funciona (texto local). No hay carga remota bloqueante.

### 3.1 Inicio / Próximo pago  *(héroe del producto)*
- **Propósito:** responder "¿cuándo pagan?" en menos de un segundo para la institución favorita.
- **Contenido clave:** card **PróximoPago** tratada como póster (fecha-héroe Fraunces), contador regresivo en días, chip de **EstadoFecha**, chip **"Fuente pública · MEF"**, nombre de institución/grupo, acceso a "cambiar institución".
- **Estados:**
  - *Cargando:* skeleton estático (placeholder, sin shimmer si reduce-motion) de la card.
  - *Vacío (sin favorito):* "¿Y tú, dónde trabajas? Elige tu institución y te digo cuándo pagan." → abre buscador.
  - *Vacío (sin fecha futura cargada):* card **Pendiente** ("El MEF aún no publica este período") o **Desactualizada** según el árbol de decisión (§4).
  - *Sin internet:* muestra la última fecha en caché con sello "Datos del {fecha_publicacion}"; sin bloqueo.
  - *Desactualizado:* banner "Estos datos podrían no estar al día" + botón **[Actualizar]** (solo si hay versión remota mayor).

### 3.2 Selección de institución (buscador)  *(sheet)*
- **Propósito:** mapear las ~33 entidades de `grupos_entidades` a su categoría y fijar el favorito. Ej.: **MIDES → GRUPO 3**.
- **Contenido clave:** campo de búsqueda (filtra por entidad o grupo), lista agrupada por categoría, ítem seleccionable como "mi institución", botón fijar/cambiar. Targets ≥48dp (público clave: adultos mayores).
- **Estados:** *Cargando:* lista esqueleto. *Vacío de búsqueda:* "No encontramos esa institución. Revisa el nombre o elige el grupo." *Sin internet:* opera sobre caché (lista de entidades es local). 

### 3.3 Calendario anual
- **Propósito:** vista de semestre/año por categoría; ver todas las quincenas y su estado.
- **Contenido clave:** selector de categoría, grilla/lista mensual (6 meses × 2 quincenas), marcador "hoy" (forma+peso+texto, no solo color), celdas con FilaCalendario (fecha + estado). **Modo lista** alterno al grid para días con pago (accesibilidad/adultos mayores).
- **Estados:**
  - *Cargando:* grilla esqueleto.
  - *Vacío / período no publicado:* la celda se pinta **Pendiente** (icono reloj + contorno punteado), NUNCA vacía ni como error.
  - *Sin internet:* caché; banner de frescura si aplica.
  - *Desactualizado:* banner + [Actualizar].

### 3.4 Detalle de quincena  *(push)*
- **Propósito:** ficha completa y verificable de UNA fecha de pago.
- **Contenido clave:** **dato primario = `fecha_pago`** en grande; estado + (si Modificada) "Antes: {fecha_anterior}"; precisión ("Aproximada" para XIII); metadatos secundarios rotulados (inicio/cierre de registro, retención ACH) en sección colapsada; bloque de **procedencia** (Fuente MEF + `data_version` + `fecha_publicacion`) y enlace de salida **"Ver en la fuente oficial (MEF)"**; CTA "Avisarme".
- **Estados:** *Cargando:* skeleton de ficha. *Sin internet:* muestra todo desde caché; el enlace MEF avisa que requiere conexión. *Desactualizado:* nota "pudo cambiar; verifica en la fuente".

### 3.5 Avisos
- **Propósito:** bandeja local de eventos relevantes: "tu fecha cambió", "se publicó el nuevo período", recordatorios programados.
- **Contenido clave:** lista cronológica de avisos generados localmente (sin backend), cada uno con estado y enlace al detalle.
- **Estados:** *Vacío:* "Aquí verás avisos cuando una fecha cambie o se publique un nuevo período." *Sin internet:* muestra avisos ya generados. *Desactualizado:* invita a actualizar para detectar cambios.

### 3.6 Fuentes y criterios
- **Propósito:** explicar el modelo "solo fuente pública", qué significan los estados y dar trazabilidad → mitiga oficialidad y responsabilidad.
- **Contenido clave:** atribución completa ("Fuente: publicaciones públicas del MEF. App no afiliada."), enlace al MEF, explicación de estados (Publicada/Modificada/Desactualizada/Pendiente) y de precisión "Aproximada" (XIII), `data_version` y fecha de los datos, enlace al repositorio open source.
- **Estados:** estático/local; *sin internet:* el enlace MEF/repo requiere conexión, el texto siempre disponible.

### 3.7 Acerca de / disclaimer
- **Propósito:** disclaimer largo legal + privacidad, como **heading semántico** (no imagen).
- **Contenido clave:** texto "App independiente y no oficial…", "no tramitamos ni resolvemos pagos; ante diferencias prevalece la fuente oficial del MEF", "sin registro ni datos personales; todo local", enlace a política de privacidad, enlace al repo, nota de que el contador depende de la hora del dispositivo.
- **Estados:** estático/local.

### 3.8 Ajustes / Recordatorios
- **Propósito:** configurar avisos locales (sin backend) y preferencias.
- **Contenido clave:** activar recordatorios (pre-prompt propio antes del diálogo del sistema), anticipación en días, hora, categorías; toggle **"Ocultar nombre de institución en notificaciones"**; dark/light/sistema; gestión del favorito; enlaces a Fuentes y Acerca de.
- **Estados:** *Sin permiso de notificaciones:* fila explica el beneficio y reabre el permiso; *Sin internet:* todo configurable offline (los recordatorios son locales).

**Estado transversal "Desactualizado":** banner persistente no intrusivo arriba del contenido, color `state.stale` + icono triángulo + texto + acción [Actualizar] (acción solo si `remoteVersion > localVersion`).

---

## 4. Patrón de los ESTADOS DE FECHA en la UI

**Regla dura (WCAG 1.4.1):** el estado NUNCA depende solo del color. Patrón obligatorio = **icono (forma única) + etiqueta de texto + color (3.er canal redundante)**, encapsulado en un único componente `EstadoFechaChip(enum)` con `mergeSemantics`. No existe API para pintar estado solo con color.

**Modelo de dos niveles (lente fechas-procedencia):** *intrínsecos* viven en la fila del dataset; *derivados* se calculan en consulta a partir de ausencia de fila + frescura. `precision` es un atributo aparte, no un estado.

| Estado | Nivel | Disparo (regla exacta) | Etiqueta UI | Icono (forma única, línea) | Color dark / texto light | Tratamiento extra | Semantics |
|---|---|---|---|---|---|---|---|
| **Publicada** | intrínseco (default v1) | La fila existe en el dataset (en v1 toda fila es Publicada salvo override). | `Publicada` | check en círculo | `#4FC78A` / `#1E7A4D` | **Fill lima** en card héroe | "Estado: publicada en fuente pública" |
| **Modificada** | intrínseco (override) | `fecha_pago` de un slot difiere entre versión local previa y nueva, o aparece en el changelog del manifest. | `Modificada` | lápiz / "cambios" | `#F2A33C` / `#9A6400` | Nota "Antes: {fecha_anterior}" | "Estado: modificada respecto a una publicación anterior" |
| **Pendiente** | derivado | No hay fila para el período y `remoteVersion == localVersion` (o antigüedad ≤ 195 d). | `Pendiente` | reloj / reloj de arena | `#9A9A93` / `#6B6A62` | Superficie neutra + **borde punteado** | "Estado: pendiente, el MEF aún no la publica" |
| **Desactualizada** | derivado | `remoteVersion > localVersion` sin actualizar; o (offline) sin fecha futura y antigüedad > 195 d, o hoy − última fecha cubierta > 14 d. | `Desactualizada` | triángulo de aviso | `#E5533D` / `#C13D26` | Banner + CTA [Actualizar] | "Estado: desactualizada, verifica en la fuente" |
| **Estimada** | intrínseco (RESERVADO Fase 2) | **Nunca se emite en v1.** Valor inesperado = no soportado. | `Estimada` | `≈` / círculo punteado | `#7C93C7` / `#3F5688` | Borde punteado; **dormido v1** | "Estado: estimada, aproximada" |
| *(precision)* **Aproximada** | atributo, no estado | Fila de `xiii_mes` (fecha aproximada del MEF). Ortogonal al estado. | `Aproximada` | `~` ondulado | `#F2B441` (marigold) | Etiqueta junto a la fecha | "Fecha aproximada del XIII Mes" |

**Reglas de presentación:**
- Las 5 formas de icono se distinguen en **escala de grises** (check ≠ reloj ≠ triángulo ≠ lápiz ≠ punteado) → protege a daltónicos. Test de release: captura en grises y verifica diferenciabilidad.
- El color del estado se ata a la **semántica del dato**: el **lima de marca solo aparece cuando la fecha está Publicada** (la card héroe se vuelve póster lima). Nunca se "celebra" con lima una fecha que el MEF no publicó (Pendiente = superficie neutra punteada). Esto comunica visualmente el modelo "solo fuente pública" de v1.
- **Decisión de conflicto (a11y vs visual en colores de estado):** se adoptan los tonos de la lente *diseño-visual* (cluster cálido/editorial) por coherencia de marca, pero validados al **floor a11y** (chip ≥4.5:1 etiqueta/fondo, icono/borde ≥3:1); donde un tono visual no llegaba como texto, se usa la variante *light* indicada.
- **Estimada para Fase 2:** cuando se active, toda fecha Estimada se rotula **"Estimación de la app — no oficial"**, jamás atribuible al MEF (regla fijada ahora).

---

## 5. Design System (resumen, listo para Flutter `ThemeData`)

Dirección: **editorial audaz / dark-first**. **NO** `ColorScheme.fromSeed` (genera tintes morados/dynamic no deseados): se construye `ThemeData` con valores explícitos + `ThemeExtension` para colores de estado.

**Decisiones de conflicto resueltas (una línea c/u):**
- *Audacia visual vs contraste accesible:* se lidera con la paleta visual (lima + near-black neutro-frío + crema cálido) **pero** ningún par texto/fondo declarado "texto esencial" baja de 4.5:1 (test rompe el build).
- *Near-black vs true-black:* se usa `#0B0B0C` (no `#000000`) y crema `#F7F5F0` (no blanco puro) para evitar halation en astigmatismo, manteniendo el look premium.
- *Anillo de foco lima (visual) vs azul (a11y):* gana **lima** `accent.primary` (8.5:1+ sobre canvas) por coherencia de marca; cumple holgado.
- *Acento secundario:* marigold `#F2B441` aprobado SOLO para XIII/favorito (<5% de superficie); el resto del sistema es monocromo lima → contención = premium, anti-slop.
- *Contador con segundos (HH:MM:SS) vs días:* gana **granularidad de día** ("Faltan N días"); evita saturar lectores de pantalla y romper textScaler. El roll animado es solo del número de días.
- *Hora `AM/PM` vs `a. m./p. m.`:* gana **`AM/PM` en mayúsculas** (preferencia Panamá del usuario).

### 5.1 Tokens de color — tabla Flutter (dark + light)

| Token (semántico) | Dart const | Dark | Light | Uso / ThemeData |
|---|---|---|---|---|
| `bg.canvas` | `C.canvas` | `#0B0B0C` | `#FAF8F2` | `scaffoldBackgroundColor`, `colorScheme.background` |
| `bg.canvasDim` | `C.canvasDim` | `#08080A` | `#F2EFE6` | Fondo recesivo tras el héroe |
| `surface.1` | `C.surface1` | `#141416` | `#FFFFFF` | `colorScheme.surface`; cards, rows |
| `surface.2` | `C.surface2` | `#1C1C1F` | `#F4F1EA` | Card "Pendiente", chips, secciones |
| `surface.3` | `C.surface3` | `#26262A` | `#ECE8DF` | Bottom sheets, menús |
| `surface.inset` | `C.inset` | `#100F12` | `#F0ECE3` | Inputs, buscador |
| `border.hairline` | `C.hairline` | `rgba(247,245,240,.08)` | `rgba(20,19,15,.08)` | Separadores, borde de card en dark |
| `border.strong` | `C.borderStrong` | `rgba(247,245,240,.16)` | `rgba(20,19,15,.14)` | Borde punteado "Pendiente", foco inset |
| `text.hi` | `C.textHi` | `#F7F5F0` | `#14130F` | `colorScheme.onSurface`; titulares, números |
| `text.mid` | `C.textMid` | `#C7C5BD` | `#46443B` | Texto secundario **esencial** (floor ≥4.5:1) |
| `text.mute` | `C.textMute` | `#9A9A93` | `#54524A` | Secundario **no esencial / grande** |
| `text.faint` | `C.textFaint` | `#6B6B66` | `#86837A` | Terciario, deshabilitado |
| `text.onAccent` | `C.onAccent` | `#0B0B0C` | `#0B0B0C` | Texto sobre lima/marigold (siempre tinta) |
| `accent.primary` | `C.accent` | `#C6F647` | `#C6F647` | `colorScheme.primary`; héroe, CTA, **focus ring** |
| `accent.primaryHover` | `C.accentHi` | `#D7FB6E` | `#D7FB6E` | Hover/pressed-light |
| `accent.primaryPressed` | `C.accentLo` | `#AEE22C` | `#AEE22C` | Pressed |
| `accent.onLightText` | `C.accentOnLight` | — | `#46610A` | Lima como TEXTO sobre claro (la lima brillante no pasa AA como texto en light) |
| `accent.secondary` | `C.marigold` | `#F2B441` | `#C8881F` | XIII / favorito (<5% superficie) |
| `state.published` | `C.stPublished` | `#4FC78A` | `#1E7A4D` | extensión `AppStateColors` |
| `state.pending` | `C.stPending` | `#9A9A93` | `#6B6A62` | `AppStateColors` |
| `state.modified` | `C.stModified` | `#F2A33C` | `#9A6400` | `AppStateColors` |
| `state.stale` | `C.stStale` | `#E5533D` | `#C13D26` | `AppStateColors` |
| `state.estimated` | `C.stEstimated` | `#7C93C7` | `#3F5688` | `AppStateColors` (dormido v1) |
| `overlay.scrim` | `C.scrim` | `rgba(0,0,0,.62)` | `rgba(20,19,15,.40)` | `BarrierColor` de sheets/diálogos |

> Mapeo `ColorScheme` manual (sin seed): `primary: accent.primary`, `onPrimary: text.onAccent`, `surface: surface.1`, `onSurface: text.hi`, `background: bg.canvas`. `useMaterial3: true` con `ThemeData` sobreescrito + `extensions: [AppStateColors(...)]`. **Regla de oro del lima:** sobre lima siempre tinta `#0B0B0C`; lima como texto solo en números display ≥40px sobre dark; nunca lima en párrafos.

### 5.2 Tipografía — escala Flutter `TextTheme`

Pareja: **Fraunces** (serif editorial variable, display/titulares/fecha-héroe) + **Space Grotesk** (grotesca técnica, UI/datos/contador/cuerpo/legal, con `FontFeature.tabularFigures()` + `lnum`). Cargar vía `google_fonts` con preload; weights congelados: Fraunces 400/560/600, Space Grotesk 450/500/600/700. Fallback de datos: mono del sistema (reservar ancho fijo del contador para que no reflowee si la fuente no carga).

| Token | Fuente | px | Weight | Line-h | Tracking | Uso | Mapeo TextTheme |
|---|---|---|---|---|---|---|---|
| `date.hero` | Fraunces | 72 | 560 | 0.92 | −0.025em | Día del héroe ("23") | `displayLarge` |
| `display.1` | Fraunces | 48 | 600 | 1.00 | −0.02em | Título de pantalla grande | `displayMedium` |
| `display.2` | Fraunces | 36 | 600 | 1.05 | −0.02em | Encabezado de sección | `displaySmall` |
| `headline` | Fraunces | 28 | 580 | 1.15 | −0.015em | Título de pantalla | `headlineMedium` |
| `title` | Fraunces | 22 | 560 | 1.20 | −0.01em | Título de card | `titleLarge` |
| `countdown.num` | Space Grotesk | 44 | 600 | 1.00 | −0.01em | Número del contador (tabular) | `headlineLarge` |
| `body.lg` | Space Grotesk | 18 | 450 | 1.50 | 0 | Texto destacado | `bodyLarge` |
| `body` | Space Grotesk | 16 | 450 | 1.50 | 0 | Cuerpo, legal/disclaimer | `bodyMedium` |
| `label.strong` | Space Grotesk | 14 | 600 | 1.20 | +0.02em | Botones, chips | `labelLarge` |
| `body.sm` | Space Grotesk | 14 | 450 | 1.45 | 0 | Secundario | `bodySmall` |
| `caption` | Space Grotesk | 13 | 500 | 1.30 | 0 | Metadatos | `labelMedium` |
| `overline` | Space Grotesk | 12 | 700 | 1.00 | +0.14em | "PRÓXIMO PAGO", "FUENTE PÚBLICA" (UPPERCASE) | `labelSmall` |
| `micro` | Space Grotesk | 11 | 600 | 1.10 | +0.12em | Ribbon "NO OFICIAL" | — |

**Reglas a11y de tipografía:** `display`/`date.hero` es el **único** token clampable (máx **1.3×** `textScaler`); `headline/title/body/label` **sin tope**, soportan ≥200% sin clipping. Fraunces solo en ≥22px (legal y datos van en Space Grotesk para legibilidad de tildes/ñ/números). Categorías del dataset se muestran en sentence/Title case (`JUBILADOS → Jubilados`, `GASTOS DE REPRESENTACION → Gastos de representación`); si se quiere look en caps, vía `letterSpacing`, con Semantics normalizado.

### 5.3 Espaciado, radios, motion

| Grupo | Tokens |
|---|---|
| **Espaciado** (base 8, sub-4) | `0·4·8·12·16·24·32·48·64·96` — padding card 24, padding pantalla 20 (móvil)/24 (tablet) |
| **Radios** | `xs 6 · sm 10 · md 14 · lg 20 · xl 28 · pill 999` — héroe `xl`, cards `lg`, chips `pill`, botones/inputs `md` |
| **Elevación (dark)** | Sin drop-shadow difusa. `elev.0/1` = superficie + hairline 1px; `elev.2` (sheets) = `surface.3` + hairline (+ sombra suave SOLO en light). Anti card-soup. |
| **Foco** | Anillo 2px `accent.primary` + 2px offset; nunca tapado por nav/banner sticky (WCAG 2.4.11/2.4.12). |
| **Touch target** | Mínimo **48×48 dp** en todo control (util `MinTapTarget`), incluidas celdas de calendario. |

| Motion token | Valor | Uso |
|---|---|---|
| `dur.instant` | 80ms | Press de chips |
| `dur.fast` | 140ms | Hover, toggles |
| `dur.base` | 220ms | Transiciones estándar, **roll de dígitos del contador** |
| `dur.slow` | 360ms | Entrada de pantalla, expand de sección |
| `dur.deliberate` | 520ms | Entrada del héroe (una sola vez) |
| `curve.standard` | `cubic-bezier(0.2,0,0,1)` | Salida decelerada (fintech serio) |
| `curve.enter` | `cubic-bezier(0.16,1,0.3,1)` | Asentado sin overshoot |
| `curve.exit` | `cubic-bezier(0.4,0,1,1)` | Salidas |
| `press.scale` | 0.98 @120ms | Feedback de toque |

**Reduce-motion (obligatorio, vía helper `AppMotion` que lee `MediaQuery.disableAnimations` + `prefers-reduced-motion`):** roll del contador → número estático; confeti "día de pago" → badge estático; transición de pantalla → fade corto; shimmer/skeleton → placeholder estático. El carácter "audaz" se mantiene en color y tipografía, **no** en movimiento obligatorio. Sin springs/bounce/glow/gradientes mesh/glassmorphism (anti-slop).

### 5.4 Internacionalización y tiempo (base lista, v1 solo español)
- Todos los strings en `app_es.arb` con plurales ICU desde el día 1 (`{n, plural, one{Falta {n} día} other{Faltan {n} días}}`), casos "Es hoy"/"Es mañana".
- Fechas: `DateFormat("EEEE d 'de' MMMM 'de' y", 'es')` → "viernes 30 de junio de 2026" (sin ordinal). Horas: 12h **`9:00 AM`**.
- **Todo cálculo de "días restantes" y el corte de medianoche usan `America/Panamá` (UTC-5, sin DST) fijo**, nunca la zona del dispositivo (evita off-by-one en Web/viajeros). `EdgeInsetsDirectional`/`AlignmentDirectional` para RTL futuro a costo cero.

---

## 6. Componentes UI reutilizables

| Componente | Responsabilidad única | Notas a11y / posicionamiento |
|---|---|---|
| **`CardProximoPago`** | Renderizar el héroe (overline "PRÓXIMO PAGO", institución, fecha-héroe Fraunces, contador, chip estado, chip fuente). Conmuta a layout **póster lima** si Publicada / **neutro punteado** si Pendiente. | El lima solo aparece en Publicada (ata color a semántica). Contador no satura lector (resumen de días). |
| **`EstadoFechaChip(enum)`** | Único punto que pinta un estado: **siempre** icono+etiqueta+color juntos (`mergeSemantics`). | Imposible mostrar estado solo por color. Golden test: 5 estados en dark/light, ratio ≥4.5:1. |
| **`ContadorRegresivo`** | Calcular y mostrar días restantes (inclusivo del día de pago) con dígitos tabulares; roll de `dur.base`. | Granularidad **día**, no segundos; `Semantics(liveRegion:true)` SOLO al cambiar el nº de días; `ExcludeSemantics` en cualquier ticker fino. Ancho fijo reservado. |
| **`FilaCalendario` / `CeldaCalendario`** | Una quincena del calendario: fecha + `EstadoFechaChip`. Celda sin fila → Pendiente (nunca vacía). | Área táctil ≥48dp aunque el glifo sea menor; "hoy"/"seleccionado" por forma+peso+texto, no solo color. |
| **`ChipFuentePublica`** | Mostrar "Fuente pública · MEF" como atribución tappable → Fuentes. | **Nunca** escudo/logo del MEF; es texto. Tap reeduca sobre quién es la autoridad. |
| **`RibbonNoOficial`** | Slim bar persistente "App independiente · No oficial" en todas las pantallas; tap → Acerca de. | Presente en árbol de **Semantics** ("aplicación independiente, no oficial, no afiliada al Gobierno"), no solo visual. |
| **`BannerDisclaimer` (onboarding)** | Pantalla/lámina de disclaimer con botón [Entendido] en primer uso. | Bloqueante; siembra el mensaje antes del uso. |
| **`BannerFrescura`** | Avisar "Datos del {fecha} · verifica actualización" o estado Desactualizada con [Actualizar]. | Acción [Actualizar] solo si `remoteVersion > localVersion`; distingue "no actualicé" de "el MEF no publica". |
| **`BuscadorInstitucion`** | Filtrar entidades→grupo y fijar favorito (MIDES→GRUPO 3). | Resultados con Semantics normalizado; targets ≥48dp; estado vacío con copy ciudadano. |
| **`BloqueProcedencia`** | En detalle: fuente MEF + `data_version` + `fecha_publicacion` (+ `fecha_anterior` si Modificada) + enlace "Ver en la fuente oficial (MEF)". | Trazabilidad = mitiga oficialidad y responsabilidad. |
| **`TarjetaAviso`** | Ítem de la bandeja Avisos (cambio de fecha / nuevo período / recordatorio), tappable al detalle. | Copy encuadrado como aviso **de la app**, no del Gobierno. |
| **`PrePromptPermiso`** | Hoja propia antes del diálogo de notificaciones del sistema. | "Los recordatorios se quedan en tu teléfono: sin servidores." Pide permiso contextual, no al arranque. |
| **`WidgetProximoPago` (Android)** | Mostrar próximo pago en home screen: nombre de app visible + institución/grupo + fecha + "Fuente pública: MEF · no oficial". | **Decisión de conflicto (póster lima vs neutro):** widget por defecto **neutro de alto contraste con acento lima** (compatibilidad de launchers + legibilidad), estado por etiqueta+forma; `contentDescription`, texto en `sp`, layout flexible a fuente máxima. Copy neutral; nombre de institución ocultable. |
| **`SkeletonCarga`** | Placeholders de carga reutilizables (héroe, lista, ficha). | Estático bajo reduce-motion. |

---

### Notas de cierre (invariantes de diseño, no negociables)
1. La fecha se muestra **verbatim**: cero corrimiento cliente por fin de semana/feriado (verificado: 0 pagos en finde; el MEF ya ajusta). Si el MEF corrige, llega como **Modificada** en nueva `data_version`.
2. El disclaimer "no oficial" es **Definition of Done** en cada superficie (pantalla, push, widget, captura de tienda) y está presente en **Semantics**, no solo como pixel.
3. Sin `ColorScheme.fromSeed`, sin morado M3, sin azul/rojo/blanco en disposición de bandera, sin escudo. Lima + serif editorial = identidad deliberadamente **no estatal**.
4. Estado de fecha = `EstadoFechaChip` (icono+etiqueta+color); el color es refuerzo, jamás portador único.
5. Cualquier color de marca nuevo pasa el **floor de contraste calculado** antes de entrar al sistema (lint/test rompe el build si un par "texto" cae bajo 4.5:1).


---

# §B — ARQUITECTURA E IMPLEMENTACIÓN

## ARQUITECTURA E IMPLEMENTACIÓN

> **Cómo se integra con lo existente:** esta capa **consume** el pipeline (`pipeline/build_dataset.py` = fuente de verdad) y el **Cloudflare Worker** (`worker/src/index.js`) **tal como están**. No se reimplementa ni el pipeline ni el Worker. El cliente Flutter es un consumidor puro de los JSON estáticos servidos en `/v1/*`, con cache offline y revalidación por `data_version`/ETag.
>
> **Invariantes que esta arquitectura hereda y protege (no se negocian):** (1) cero SDK de terceros — sin analítica, crash, ads ni fuentes remotas; (2) ETag global `"v{data_version}"`, sin identificadores por usuario; (3) alarmas **inexactas** (sin `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`); (4) disclaimer "no oficial" + atribución "Fuente pública: MEF" **omnipresentes y en el árbol de Semantics**; (5) `fecha_pago` se muestra **verbatim**, sin corrimientos por feriado/fin de semana; (6) toda noción de "hoy" pasa por `hoyPanama()` (UTC-5, sin DST).

---

### 1. Estilo de arquitectura

**Clean Architecture pragmática, organizada feature-first** sobre un núcleo compartido. Para una app de una sola feature dominante (consultar fechas) se evita la sobre-ingeniería de paquetes separados, pero se respetan las fronteras de dependencia: **la UI depende del dominio; el dominio no depende de nada de Flutter ni de la red.** Esto hace testeable en Dart puro la lógica crítica (`proximoPago`, `hoyPanama`, diff de "Modificada"), que es exactamente donde viven los riesgos de off-by-one.

**Cuatro capas (dependencia siempre hacia adentro):**

| Capa | Responsabilidad | Conoce a |
|---|---|---|
| **presentation** | Widgets, pantallas, tema/tokens, controladores de estado (Riverpod), Semantics, animaciones, disclaimer/atribución. | application, domain |
| **application** | Casos de uso / controladores que orquestan (obtener próximo pago, refrescar datos, programar recordatorios). Exponen estado a la UI. | domain |
| **domain** | Entidades inmutables, enums, *interfaces* de repositorio y **lógica pura**: `hoyPanama()`, `proximoPago()`, `etiquetaContador()`, `detectarModificadas()`. **Cero imports de Flutter.** | nada |
| **data** | Implementación de repositorios; datasource remoto (Worker), local (SQLite/drift), preferencias (shared_preferences) y la **semilla** empaquetada. Mapea DTO↔entidad. | domain |

**Diagrama de flujo de datos (lado app):**

```
                       ┌───────────────────────────────────────────────┐
   PIPELINE + WORKER   │   Cloudflare Worker (worker/src/index.js)       │
   (ya existen, NO se  │   /v1/version  ·  /v1/all                       │
    tocan)             │   ETag "v{data_version}"  ·  304  ·  CORS *     │
                       └───────────────────────┬───────────────────────┘
                                                │  GET (anónimo, HTTPS)
                                                │  If-None-Match: "v{local}"
                ┌───────────────────────────────▼─────────────────────────────┐
   DATA         │  RemoteDataSource (http)                                      │
                │    • versionCheck() -> /v1/version  (cache 300s)              │
                │    • fetchAll(etag) -> /v1/all  | 304 => sin cambios          │
                ├──────────────────────────────────────────────────────────────┤
                │  CalendarioRepository (impl)                                  │
                │    1. al instalar: hidrata DB desde assets/seed/all.json      │
                │    2. al abrir: versionCheck(); si remote>local => fetchAll   │
                │    3. diff fecha_pago por slotKey -> tabla 'cambios'          │
                │    4. swap atómico de la DB + persiste data_version           │
                │    5. dispara reprogramación de notificaciones                │
                ├───────────────┬───────────────────────┬──────────────────────┤
                │ LocalDataSource│ PrefsDataSource        │ SeedAsset            │
                │ (drift/SQLite) │ (shared_preferences)   │ (bundle JSON v_seed) │
                └───────┬────────┴───────────┬────────────┴──────────────────────┘
                        │ queryProximo(...)   │ favorito / recordatorios / UI
                ┌───────▼─────────────────────▼────────────────────────────────┐
   DOMAIN       │  proximoPago(seleccion):                                      │
                │    hoy = hoyPanamaIso()                                        │
                │    fila = SELECT ... fecha_pago >= :hoy ORDER BY .. LIMIT 1    │
                │    estado = derivar(fila, remoteVersion, frescura)            │
                │    -> ProximoPago{entrada, estado, diasRestantes, procedencia}│
                └───────────────────────────────┬──────────────────────────────┘
                                                │  AsyncValue<ProximoPago>
                ┌───────────────────────────────▼──────────────────────────────┐
   PRESENTATION │  HomeController (Riverpod)  ->  Card "PRÓXIMO PAGO" (póster)   │
                │  Calendario · Detalle/Procedencia · Acerca de · Avisos        │
                │  + Badge "No oficial" (Semantics) + chip "Fuente pública: MEF"│
                └───────────────────────────────┬──────────────────────────────┘
                                                │ saveWidgetData()
                                                ▼
                            Widget Android (home_widget + RemoteViews)
```

---

### 2. Árbol de carpetas (`lib/`)

```
lib/
├── main.dart                         # bootstrap: tz America/Panama, ProviderScope, runApp
├── app.dart                          # MaterialApp.router, tema dark/light, l10n delegates
│
├── core/                             # transversal, sin lógica de negocio
│   ├── di/
│   │   └── providers.dart            # providers raíz (db, http, prefs, repos) — Riverpod
│   ├── result/
│   │   └── resultado.dart            # Resultado<T> / fallos tipados (sin excepciones crudas)
│   ├── time/
│   │   ├── hoy_panama.dart           # hoyPanama() / hoyPanamaIso() — UTC-5 fijo, sin DST
│   │   └── tz.dart                   # init zona America/Panama (package: timezone)
│   ├── format/
│   │   ├── fecha_format.dart         # intl: "viernes 30 de junio de 2026" (locale es)
│   │   └── hora_format.dart          # 12h AM/PM
│   ├── constants/
│   │   └── umbrales.dart             # kUmbralStaleDias=195, kMargenCoberturaDias=14, kWorkerBaseUrl
│   └── motion/
│       └── app_motion.dart           # lee disableAnimations / prefers-reduced-motion
│
├── design/                           # design system "editorial audaz / dark-first"
│   ├── tokens.dart                   # C (colores), Space, Radius, Dur, Curve — NO ColorScheme.fromSeed
│   ├── theme.dart                    # ThemeData dark+light + ThemeExtension AppStateColors
│   ├── typography.dart               # Fraunces (display) + Space Grotesk (datos, tabular)
│   └── widgets/
│       ├── estado_fecha_chip.dart    # icono(forma) + etiqueta + color, mergeSemantics (WCAG 1.4.1)
│       ├── disclaimer_badge.dart     # "No oficial · Proyecto independiente" + Semantics
│       ├── fuente_publica_chip.dart  # "Fuente pública: MEF" (NUNCA logo/escudo)
│       └── contador_regresivo.dart   # número héroe tabular, ExcludeSemantics en segundos
│
├── l10n/
│   ├── app_es.arb                    # único locale v1, plurales ICU (día/días)
│   └── app_localizations.dart        # generado
│
├── domain/                           # Dart puro — CERO import de Flutter/red
│   ├── entities/
│   │   ├── categoria.dart            # enum Categoria (+ wire/display)
│   │   ├── entidad.dart              # Entidad { nombre, grupo: Categoria }
│   │   ├── entrada_calendario.dart   # EntradaCalendario (fila tidy)
│   │   ├── estado_fecha.dart         # enum EstadoFecha + Precision
│   │   ├── seleccion.dart            # Seleccion: categoría directa | entidad
│   │   ├── proximo_pago.dart         # ProximoPago (resultado de la consulta núcleo)
│   │   ├── manifest.dart             # Manifest + Cambio
│   │   └── prefs_usuario.dart        # PrefsUsuario
│   ├── repositories/
│   │   ├── calendario_repository.dart   # interfaz
│   │   └── prefs_repository.dart        # interfaz
│   └── logic/
│       ├── proximo_pago.dart         # proximoPago() + árbol de estados derivados
│       ├── contador.dart             # etiquetaContador(): "Te pagan hoy/mañana/Faltan N"
│       └── diff_modificadas.dart     # slotKey() + detectarModificadas()
│
├── data/
│   ├── remote/
│   │   ├── worker_api.dart           # GET /v1/version, /v1/all (ETag/304, timeout)
│   │   └── dto/                      # *_dto.dart con fromJson exacto al wire del Worker
│   ├── local/
│   │   ├── app_database.dart         # drift: tablas calendario, grupos, xiii, cambios
│   │   ├── calendario_dao.dart       # queryProximo, ultimaFechaCubierta, swap atómico
│   │   └── prefs_local.dart          # shared_preferences
│   ├── seed/
│   │   └── seed_loader.dart          # carga assets/seed/all.json (offline desde el 1er arranque)
│   └── repositories/
│       ├── calendario_repository_impl.dart
│       └── prefs_repository_impl.dart
│
├── application/
│   ├── home_controller.dart          # AsyncNotifier<ProximoPago> (Riverpod)
│   ├── sync_controller.dart          # versionCheck + fetchAll + diff + swap + reprogramar
│   ├── favorito_controller.dart      # selección de "mi institución"
│   └── recordatorios_controller.dart # programar/cancelar notificaciones locales
│
├── notifications/
│   ├── notificaciones_service.dart   # flutter_local_notifications (zonedSchedule, INEXACTO)
│   └── reprogramador.dart            # recalcula y reprograma tras update/boot/medianoche
│
├── widget_android/
│   └── home_widget_bridge.dart       # home_widget.saveWidgetData + updateWidget
│
└── features/
    ├── home/                         # próximo pago + contador + disclaimer
    ├── calendario/                   # calendario anual por categoría (celdas con estado)
    ├── detalle/                      # ficha de fecha + procedencia + "Ver en fuente MEF"
    ├── favorito/                     # elegir institución/grupo
    ├── avisos/                       # configurar recordatorios (pre-prompt de permiso)
    ├── fuentes/                      # panel de fuentes/criterios + modelo "solo fuente pública"
    └── acerca/                       # disclaimer largo + privacidad + repo open source
```

Carpetas nativas afectadas (no en `lib/`): `android/app/src/main/res/layout/widget_*.xml` (RemoteViews), `android/app/src/main/AndroidManifest.xml` (permisos + remoción AD_ID + receiver de notificaciones), `ios/Runner/PrivacyInfo.xcprivacy`, `assets/seed/all.json`, `assets/fonts/` (Fraunces, Space Grotesk **self-host**).

---

### 3. Modelos de dominio

```dart
// ───────── categoria.dart ─────────
/// Las 5 categorías del dataset. `wire` = string EXACTO del Worker (MAYÚSCULAS);
/// `display` = forma normalizada para UI/Semantics (sentence case, a11y).
enum Categoria {
  jubilados('JUBILADOS', 'Jubilados'),
  gastosRepresentacion('GASTOS DE REPRESENTACION', 'Gastos de representación'),
  grupo1('GRUPO 1', 'Grupo 1'),
  grupo2('GRUPO 2', 'Grupo 2'),
  grupo3('GRUPO 3', 'Grupo 3');

  const Categoria(this.wire, this.display);
  final String wire;
  final String display;
  static Categoria fromWire(String s) =>
      Categoria.values.firstWhere((c) => c.wire == s);
}

// ───────── entidad.dart ─────────
/// Fila de grupos_entidades. En el dataset SOLO existen entidades para GRUPO 1/2/3
/// (33 entidades). JUBILADOS y GASTOS DE REPRESENTACION se eligen como Categoría directa.
class Entidad {
  final String nombre;     // ej. "Min. de Desarrollo Social"
  final Categoria grupo;   // join: calendario.categoria == grupos_entidades.grupo
  const Entidad({required this.nombre, required this.grupo});
}

// ───────── seleccion.dart ─────────
/// "Mi institución": el usuario puede fijar una Categoría directa o una Entidad.
/// Ambas resuelven a una Categoria para consultar el calendario.
sealed class Seleccion {
  Categoria get categoria;
  String get etiqueta;
}
class SeleccionCategoria extends Seleccion {
  final Categoria cat;
  SeleccionCategoria(this.cat);
  @override Categoria get categoria => cat;
  @override String get etiqueta => cat.display;
}
class SeleccionEntidad extends Seleccion {
  final Entidad entidad;
  SeleccionEntidad(this.entidad);
  @override Categoria get categoria => entidad.grupo;
  @override String get etiqueta => entidad.nombre; // ej. "MIDES" / nombre completo
}

// ───────── entrada_calendario.dart ─────────
/// Una fila tidy del calendario. `fechaPago` se guarda como String ISO 'YYYY-MM-DD'
/// (canónico para comparación lexicográfica == cronológica). DateTime solo para formatear.
/// `estado`/`precision` son INTRÍNSECOS y forward-compatible: si el wire no los trae,
/// se asume Publicada/exacta por construcción (v1 = "solo fuente pública").
class EntradaCalendario {
  final int anio;
  final int semestre;          // 1 | 2
  final String mes;            // "ENERO" (wire); display vía mapa
  final int mesNum;            // 1..12
  final Categoria categoria;
  final int quincena;          // 1 | 2
  final String inicioRegistro; // ISO — metadato secundario (solo detalle)
  final String cierreRegistro; // ISO — metadato secundario
  final String retencionAch;   // ISO — metadato secundario
  final String fechaPago;      // ISO — DATO PRIMARIO ("cuándo pagan")
  final EstadoFecha estado;    // default: EstadoFecha.publicada
  final Precision precision;   // default: Precision.exacta

  const EntradaCalendario({
    required this.anio, required this.semestre, required this.mes,
    required this.mesNum, required this.categoria, required this.quincena,
    required this.inicioRegistro, required this.cierreRegistro,
    required this.retencionAch, required this.fechaPago,
    this.estado = EstadoFecha.publicada, this.precision = Precision.exacta,
  });

  DateTime get fechaPagoDate => DateTime.parse('${fechaPago}T00:00:00Z');
  /// Clave de slot estable para el diff de "Modificada".
  String get slotKey => '$anio-S$semestre|$mesNum|${categoria.wire}|$quincena';
}

// ───────── estado_fecha.dart ─────────
/// Modelo de DOS NIVELES:
///  • Tier A (intrínseco, vive en la fila): publicada, modificada, estimada(reservado).
///  • Tier B (derivado en la consulta por ausencia/frescura): pendiente, desactualizada.
/// `estimada` permanece en el enum pero NUNCA se emite en v1 (Fase 2, motor de estimación).
enum EstadoFecha { publicada, modificada, pendiente, desactualizada, estimada }

/// Atributo ORTOGONAL al estado. El XIII Mes es 'aproximada' (sigue siendo fuente pública).
enum Precision { exacta, aproximada }

// ───────── proximo_pago.dart ─────────
/// Resultado de la consulta núcleo. Adjunta procedencia para alimentar el panel de
/// Fuentes y el disclaimer "no oficial" (trazabilidad).
class ProximoPago {
  final EntradaCalendario? entrada; // null si no hay fecha futura (Pendiente/Desactualizada)
  final EstadoFecha estado;
  final int diasRestantes;          // inclusivo: 0 => "Te pagan hoy"
  final Seleccion seleccion;
  // Procedencia
  final String fechaPublicacion;    // manifest.fecha_publicacion
  final int dataVersion;            // manifest.data_version
  final String fuenteUrl;           // manifest.fuente (MEF)
  final String? fechaAnterior;      // si estado == modificada
  final Precision precision;

  bool get hayFecha => entrada != null;
  const ProximoPago({
    required this.entrada, required this.estado, required this.diasRestantes,
    required this.seleccion, required this.fechaPublicacion, required this.dataVersion,
    required this.fuenteUrl, this.fechaAnterior, this.precision = Precision.exacta,
  });
}

// ───────── manifest.dart ─────────
/// Mapea 1:1 al payload del Worker. `cambios` y `semestresMeta` son OPCIONALES:
/// se consumen si el pipeline los emite (changelog autoritativo), si no, null.
class Manifest {
  final int dataVersion;
  final String fechaPublicacion;     // ISO
  final List<String> semestres;      // ["2026-S1","2026-S2"]
  final String fuente;               // URL pública del MEF
  final int totalFilas;
  final Map<String, int> conteo;     // {"2026-S1":60,...}
  final List<Cambio>? cambios;       // changelog autoritativo (forward-compatible)
  const Manifest({
    required this.dataVersion, required this.fechaPublicacion,
    required this.semestres, required this.fuente, required this.totalFilas,
    required this.conteo, this.cambios,
  });
}
class Cambio {
  final String clave;          // slotKey
  final String fechaAnterior;  // ISO
  final String fechaNueva;     // ISO
  final int desdeVersion;
  const Cambio({required this.clave, required this.fechaAnterior,
    required this.fechaNueva, required this.desdeVersion});
}

// ───────── prefs_usuario.dart ─────────
/// TODO local. Nada se transmite ni se ata a una identidad (premisa 6 / lente privacidad).
/// `seleccionFavorita` se serializa discriminada: "cat:GRUPO 3" | "ent:Min. de Desarrollo Social".
class PrefsUsuario {
  final String? seleccionFavorita;     // null = sin favorito (estado vacío del Home)
  final bool recordatoriosActivos;
  final int diasAnticipacion;          // ej. 1 (víspera). Granularidad de DÍA.
  final int horaRecordatorioMin;       // minutos desde medianoche (ej. 480 = 8:00 AM)
  final bool ocultarNombreInstitucion; // copy neutral en lock screen/widget
  final TemaModo temaModo;             // sistema | claro | oscuro
  final bool onboardingVisto;
  final bool disclaimerAck;            // "Entendido" del onboarding (no oficial)
  final int ultimaDataVersion;         // para detectar dataset nuevo / diff
  final String? ultimoChequeoIso;      // último versionCheck

  const PrefsUsuario({
    this.seleccionFavorita, this.recordatoriosActivos = false,
    this.diasAnticipacion = 1, this.horaRecordatorioMin = 480,
    this.ocultarNombreInstitucion = false, this.temaModo = TemaModo.sistema,
    this.onboardingVisto = false, this.disclaimerAck = false,
    this.ultimaDataVersion = 0, this.ultimoChequeoIso,
  });
}
enum TemaModo { sistema, claro, oscuro }
```

---

### 4. Gestión de estado y almacenamiento local

**Gestión de estado: Riverpod (`flutter_riverpod` + `riverpod_annotation`/codegen).**
Razón: (1) la lógica de negocio queda fuera del `BuildContext`, testeable en Dart puro — alineado con la frontera "domain sin Flutter"; (2) `AsyncValue<T>` modela nativamente los tres estados de una app offline-first (cargando / dato / error) y encaja con el árbol de estados derivados (Pendiente/Desactualizada); (3) los providers son la inyección de dependencias del proyecto (no se añade `get_it`); (4) es puro Dart, sin SDK externo, sin telemetría — respeta la postura privacy-first. Se descarta **Bloc** (más boilerplate para un flujo simple) y **provider plano** (menos seguridad de tipos y peor manejo de async).

**Almacenamiento local: dos almacenes complementarios.**

1. **SQLite vía `drift`** para el dataset del calendario (tablas `calendario`, `grupos_entidades`, `xiii_mes`, `cambios`).
   Razón: (1) `ARQUITECTURA.md` ya compromete SQLite y el reemplazo de base local por versión; (2) la consulta núcleo es relacional y la especifica la lente fechas-procedencia — `SELECT ... WHERE entidad=? AND fecha_pago >= :hoy ORDER BY fecha_pago LIMIT 1` (ISO lexicográfico = cronológico); el diff de "Modificada" por `slotKey` también es naturalmente relacional; (3) future-proof para Fase 2 (más semestres, motor de estimación). `drift` da consultas tipadas, migraciones y **soporte Web vía WASM** (`sqlite3.wasm` + worker).
   *Conflicto resuelto (120 filas son pocas para una BD):* se usa SQLite igual por coherencia con el repo y Fase 2, **pero** se hidrata un snapshot inmutable en memoria para el tick del contador, de modo que el contador por segundo nunca golpea la BD.

2. **`shared_preferences`** para `PrefsUsuario` (favorito, recordatorios, tema, `ultimaDataVersion`, ack del disclaimer).
   Razón: clave-valor diminuto respaldado por `NSUserDefaults`/`SharedPreferences`; ya contemplado en `PrivacyInfo.xcprivacy` (razón requerida `CA92.1`). El respaldo del sistema (Auto Backup/iCloud) queda **encendido y divulgado** (buena UX al cambiar de teléfono); el favorito nunca va a logs y es ocultable en lock screen/widget.

Ningún dato se cifra a mano (no hay secretos): el cifrado en tránsito es HTTPS del Worker y en reposo es el sandbox del SO.

---

### 5. Capa de datos: Worker, offline-first y reprogramación

**Contrato consumido (del Worker existente):**
- `GET /v1/version` → `{ data_version, fecha_publicacion, semestres, total_filas }` (cache 300 s). Es el **chequeo barato** al abrir.
- `GET /v1/all` → `{ manifest, calendario, grupos_entidades, xiii_mes }` (un solo request trae todo). ETag `"v{data_version}"`; con `If-None-Match` devuelve **304** si no cambió.
- CORS abierto y `data_version` como única señal de frescura. **El cliente no envía ningún header identificante** (solo `If-None-Match` con el ETag global) — invariante de privacidad.

**Flujo offline-first (semilla → cache → versión → ETag/304):**

1. **Semilla empaquetada.** El build incluye `assets/seed/all.json` (snapshot de `/v1/all` con su `data_version` de compilación). En el **primer arranque sin red**, `SeedLoader` hidrata la BD: la app es 100% funcional offline desde el segundo cero.
2. **Hidratación.** Si la BD está vacía o su `data_version` < semilla, se siembra desde el asset. La BD es la fuente para todas las consultas.
3. **Chequeo al abrir.** `SyncController` llama `versionCheck()` → `/v1/version`. Compara `remote.data_version` vs `prefs.ultimaDataVersion`.
   - `remote == local` → nada que bajar (puede haber **Pendiente**: el MEF aún no publica el siguiente período).
   - `remote > local` → descarga.
4. **Descarga revalidada.** `fetchAll(etag: '"v$local"')` a `/v1/all`. Si el borde responde **304**, no hay payload (ahorro). Si **200**, se procesa el nuevo dataset.
5. **Diff de "Modificada".** Antes de reemplazar, `detectarModificadas(viejo, nuevo)` compara `fecha_pago` por `slotKey`; los cambios se escriben en la tabla `cambios`. Si el manifest trae `cambios` (changelog autoritativo del pipeline), se **unen** con el diff local para que las instalaciones nuevas (sin cache previa) también vean el badge "Modificada".
6. **Swap atómico.** Se reemplaza el contenido de la BD en una transacción y se persiste `ultimaDataVersion = remote`. Sin estados intermedios visibles.
7. **Frescura / Desactualizada (offline o sin actualizar):** se aplica la regla compuesta de la lente fechas-procedencia — `remoteVersion > localVersion` (accionable: "Actualizar"); o sin fecha futura y `(hoy − fecha_publicacion) > 195 d` o `(hoy − última_fecha_cubierta) > 14 d`. Distinto de **Pendiente** (no accionable). Banner persistente "Datos del {fecha_publicacion}".

**Reprogramación de notificaciones al actualizar.** Tras un swap exitoso (paso 6), `SyncController` invoca `Reprogramador.reprogramar()`:
1. cancela todas las notificaciones locales programadas;
2. recalcula `proximoPago(favorito)` con el dataset nuevo;
3. reprograma el/los recordatorios (víspera + día) en hora de Panamá;
4. si un `slotKey` favorito quedó **Modificada**, programa además un aviso "Tu fecha de pago cambió";
5. resuelve cualquier "Avísame cuando se publique" que ya tenga fecha.
También se reprograma en **boot** (receiver de `flutter_local_notifications`, permiso `RECEIVE_BOOT_COMPLETED`) y al volver a primer plano cruzando medianoche-Panamá (recalcula el contador y, si cambió el próximo pago, reprograma).

---

### 6. Notificaciones locales y Widget Android

**Notificaciones locales — `flutter_local_notifications` + `timezone`.**
- Programación con `zonedSchedule(...)` anclada a `tz America/Panama` (UTC-5, sin DST), con **`AndroidScheduleMode.inexactAllowWhileIdle`** — **alarmas inexactas** (granularidad de día). **No** se declaran `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`: evita el panel especial de Android 12+/14 y la revisión de política de Play (lentes privacidad + tiendas).
- Permiso **contextual con pre-prompt propio** al activar el primer recordatorio (no en frío al arranque). En Android 13+ es `POST_NOTIFICATIONS` runtime; en iOS, `UNUserNotificationCenter`.
- **Copy anti-suplantación + privacidad:** cada notificación lleva el nombre de la app como prefijo y encuadre de "recordatorio de la app", nunca "el Gobierno te paga". Copy **neutral por defecto** ("Una fecha de pago se acerca"); detalle de institución solo si el usuario activa el ajuste, y opción "Ocultar nombre de institución" para lock screen.

**Widget de pantalla de inicio Android — `home_widget`.**
- La app escribe el estado con `HomeWidget.saveWidgetData(...)` y refresca con `HomeWidget.updateWidget(...)` tras cada update de datos o cambio de favorito. El layout nativo es **RemoteViews** (`res/layout/widget_*.xml`).
- Contenido (legal-safe): nombre de la app visible (`¿Cuándo pagan?`), `{favorito} · {Categoría} — Próximo pago: {fecha}`, y atribución `Fuente pública: MEF · no oficial`. **Sin escudo, bandera ni logo del MEF.** El estado se comunica por **etiqueta de texto** (no solo color); variante de alto contraste para launchers monocromos.
- *Conflicto resuelto (póster lime vs compatibilidad de launchers):* el widget v1 usa por defecto una variante **neutra de alto contraste** (borde + texto), no el bloque lime sólido, para sobrevivir temas de fabricante y modo monocromo.

**Degradación por plataforma:**

| Plataforma | Notificaciones | Widget |
|---|---|---|
| **Android** | Sí (inexactas, contextual, neutral). | Sí (`home_widget` + RemoteViews). |
| **iOS** | Sí (`UNUserNotificationCenter`, contextual). | No en v1 (WidgetKit vía `home_widget` queda para Fase 2; degrada sin error). |
| **Web** | **Best-effort/desactivadas** — sin push backend no disparan con la pestaña cerrada; en la ficha web no se prometen recordatorios. La app cae a contador + calendario. | No aplica (`home_widget` es no-op en web; la feature se oculta por flag de plataforma). |

---

### 7. Paquetes (`pubspec.yaml`) y para qué

| Paquete | Para qué | Nota |
|---|---|---|
| `flutter_riverpod` | Gestión de estado + DI. | Núcleo de la app. |
| `riverpod_annotation` + `riverpod_generator` + `build_runner` | Codegen de providers (dev). | Solo dev. |
| `drift` + `drift_flutter` | SQLite tipado (calendario, grupos, xiii, cambios). | Web vía `sqlite3.wasm`. |
| `sqlite3_flutter_libs` | Binarios SQLite nativos (Android/iOS). | — |
| `path_provider` | Ruta del archivo de BD. | `PrivacyInfo` cubre file-timestamp. |
| `shared_preferences` | `PrefsUsuario` (favorito, recordatorios, tema, versión). | `PrivacyInfo` `CA92.1`. |
| `http` | GET anónimos al Worker (`/v1/version`, `/v1/all`) con ETag/304. | Mínimo; se descarta `dio` por evitar peso/superficie. |
| `flutter_local_notifications` | Recordatorios locales (inexactos, zonedSchedule). | Receiver de boot. |
| `timezone` | Zona `America/Panama` fija para scheduling y `hoyPanama`. | Sin `flutter_timezone`: se fija Panamá. |
| `home_widget` | Widget Android (y WidgetKit iOS en Fase 2). | RemoteViews nativo. |
| `intl` + `flutter_localizations` | Formato de fecha/hora locale `es`, plurales ICU. | Base i18n lista. |
| `google_fonts` | Fraunces + Space Grotesk. | **Self-host obligatorio:** fuentes empaquetadas como assets y `GoogleFonts.config.allowRuntimeFetching = false` (privacidad: sin fonts remotas). |
| `url_launcher` | "Ver en la fuente oficial (MEF)", repo, política. | — |
| `package_info_plus` | Versión de app en "Acerca de". | Opcional. |
| `flutter_lints` (o `very_good_analysis`) | Lint. | Dev. |

**Prohibidos por gobernanza (check de CI que rompe el build):** `firebase_analytics`, `firebase_crashlytics`, `sentry_flutter`, `amplitude`, `google_mobile_ads`, `appsflyer`, `facebook_*`, y cualquier uso de `AdvertisingIdClient`/`ATTrackingManager`. `AndroidManifest` declara `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>`.

---

### 8. Secuencia de construcción (hitos incrementales)

> Cada hito es entregable y deja la app funcionando. Ejecutar con **subagente fresco por tarea + review entre tareas** (preferencia del usuario).

| Hito | Entregable | Cierra riesgo de |
|---|---|---|
| **0. Andamiaje** | Proyecto Flutter (Android/iOS/Web), `ProviderScope`, tema dark/light con `tokens.dart` (sin `ColorScheme.fromSeed`), `app_es.arb`, fuentes self-host, **check de CI de dependencias prohibidas**, manifest Android (AD_ID removido, sin alarmas exactas). | Slop visual, deriva de telemetría. |
| **1. Dominio + lógica pura** | Entidades + enums + `hoyPanama()`, `proximoPago()`, `etiquetaContador()`, `detectarModificadas()` con **tests unitarios** (off-by-one, inclusividad "hoy", finde verbatim). | Off-by-one del contador. |
| **2. Datos offline-first** | `assets/seed/all.json`, esquema drift, `WorkerApi` (version/all + ETag/304), `CalendarioRepository` (hidratar → chequear → diff → swap). | Funcionar sin red; frescura. |
| **3. Home + contador** | Card "PRÓXIMO PAGO" (póster lima si Publicada / neutra punteada si Pendiente), contador héroe tabular, `EstadoFechaChip`, **DisclaimerBadge en Semantics**, `fuente_publica_chip`. | Confusión "oficial", a11y. |
| **4. Calendario + detalle** | Calendario anual por categoría (celdas con estado, área táctil ≥48dp), ficha de fecha con procedencia + "Ver en fuente oficial (MEF)". | Trazabilidad, percepción de verdad absoluta. |
| **5. Favorito** | Selección "mi institución" (Categoría directa o Entidad→Grupo; MIDES = GRUPO 3), persistencia en prefs, estado vacío. | UX núcleo. |
| **6. Notificaciones** | Pre-prompt contextual, scheduling **inexacto** en hora Panamá, copy neutral + ocultar institución, **reprogramación tras update/boot/medianoche**. | Negación de permiso, suplantación en push. |
| **7. Widget Android** | `home_widget` + RemoteViews neutro alto contraste, refresco tras update, atribución "no oficial". | Compatibilidad de launchers. |
| **8. Fuentes + Acerca de + Privacidad** | Panel de fuentes/criterios (modelo "solo fuente pública"), disclaimer largo, enlace a política y repo open source. | Definition of Done legal. |
| **9. Pulido a11y + temas** | Pase WCAG AA: `textScaler` ≥200% (clamp solo al token display), Semantics del contador sin live por segundo, golden tests de los 5 estados en escala de grises, reduce-motion. | Trampa de grises, daltonismo, vértigo. |
| **10. Web + assets de tienda** | Build Web (drift WASM, fonts self-host, notificaciones best-effort/off), screenshots con overlay "No oficial", notas al revisor, content rating. | Rechazo en review, SEO. |

**Definition of Done transversal (bloqueante en todos los hitos):** ninguna pantalla, push, widget ni captura se aprueba sin (a) atribución "Fuente pública: MEF", (b) disclaimer "no oficial" perceptible **también en Semantics**, (c) estados que no dependan solo del color, y (d) cero dependencia prohibida.

**Archivos relevantes del repo (consumidos, no modificados):** `/Users/alexisgarcia/proyectos/calendario-pago-pa/worker/src/index.js` (endpoints `/v1/version`, `/v1/all`, ETag/304), `/Users/alexisgarcia/proyectos/calendario-pago-pa/data/manifest.json` (contrato de `Manifest`), `/Users/alexisgarcia/proyectos/calendario-pago-pa/data/calendario.json` (shape de `EntradaCalendario`), `/Users/alexisgarcia/proyectos/calendario-pago-pa/data/grupos_entidades.json` (shape de `Entidad`), `/Users/alexisgarcia/proyectos/calendario-pago-pa/data/xiii_mes.json` (XIII = `Precision.aproximada`), `/Users/alexisgarcia/proyectos/calendario-pago-pa/pipeline/build_dataset.py` (source of truth; aquí se sugiere — sin implementar — emitir `estado`, `precision` por fila y `cambios`/`semestres_meta` en el manifest).


---

# §C — CUMPLIMIENTO, LEGAL Y TEXTOS

## Cumplimiento, legal y textos

> Esta sección es la **fuente única de verdad** para todo el copy legal, de marca y de tiendas de *¿Cuándo Pagan?*. Los textos de aquí se reutilizan literalmente (no se reescriben por pantalla). El principio rector es el riesgo declarado ALTO: como las fechas mostradas **son las oficiales reales del MEF**, el usuario tenderá a creer que la app es del Gobierno. Todo lo de abajo neutraliza esa percepción de forma redundante y estructural.

## Resolución de conflictos entre lentes (una línea cada uno)

| Conflicto | Decisión tomada |
|---|---|
| Audacia visual (lima eléctrica) vs. contraste WCAG AA | El lima `#C6F647` **solo se usa como fondo con tinta negra encima o como número grande**, nunca como texto de cuerpo: mantiene el golpe editorial y cumple AA/AAA. |
| Notificación "Te pagan mañana" (intuitiva) vs. anti-suplantación | Por defecto la notificación es **neutral y prefijada con el nombre de la app**; el detalle con institución es **opt-in** y se encuadra como "según el MEF… verifica en la fuente", nunca como anuncio oficial de pago. |
| Contador "Te pagan hoy" (dato lens) vs. voz de marca "cae tu quincena" | **Dentro de la app** se permite "Te pagan hoy / mañana" (la app habla en su propia voz, con disclaimer omnipresente); la voz de marca "cae" se usa en hero y onboarding. Ambas conviven; lo prohibido es ese tono en push/widget sin atribución. |
| Nombre con signos "¿ ?" vs. límites de tiendas/URL | Marca = **¿Cuándo Pagan?**; nombre técnico en tiendas, dominio y handles = **Cuándo Pagan** (sin signos). |
| Respaldar favorito (buena UX) vs. dato que insinúa condición de beneficiario | Se respalda vía backup cifrado del SO (atado a la cuenta del usuario, no a la nuestra) y se ofrece **"Ocultar nombre de institución en notificaciones"** para pantalla de bloqueo. |
| "Te pagan hoy" inclusivo (dato lens) vs. fricción de onboarding (legal) | Se mantiene el **paso explícito "Entendido"** en onboarding (riesgo ALTO lo justifica) y el contador inclusivo del día de pago. |

---

## 1. Disclaimers (versión final redactada)

### 1.1 Disclaimer corto — 1 línea para UI / banner / primera línea de ficha de tienda
> **App independiente y no oficial. No representa al Gobierno de Panamá ni al MEF.**

### 1.2 Badge persistente (poco espacio, pantalla principal y widget)
> **No oficial · Proyecto independiente**

Etiqueta semántica obligatoria (lector de pantalla, no solo visual):
> *"Aviso: aplicación independiente, no oficial, no afiliada al Gobierno de Panamá."*

### 1.3 Disclaimer largo — pantalla "Acerca de" (texto final)
> **Acerca de esta app**
>
> *¿Cuándo Pagan?* es un proyecto **independiente, gratuito y de código abierto**, hecho por la ciudadanía. **No es una aplicación oficial del Gobierno de Panamá.** No está afiliada, patrocinada, avalada ni administrada por el Ministerio de Economía y Finanzas (MEF) ni por ninguna entidad del Estado.
>
> Las fechas que ves son las **fechas oficiales de pago publicadas por el MEF en sus canales públicos**, transcritas aquí para que sean más fáciles de consultar. Esta app **solo organiza y muestra información que ya es pública**; no genera, no modifica ni decide fechas de pago, y **no tramita ni resuelve pagos**.
>
> La información oficial y definitiva siempre está en los canales del MEF:
> **https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/**
> Ante cualquier diferencia, **prevalece la fuente oficial del MEF**.
>
> Esta app **no requiere registro ni recolecta datos personales**; todo se guarda en tu dispositivo.

### 1.4 Matriz de presencia del disclaimer (Definition of Done — bloqueante para release)

| Superficie | Qué se muestra | Bloqueante |
|---|---|---|
| Onboarding (1er uso) | Disclaimer corto (1.1) en pantalla propia + botón "Entendido" | Sí |
| Ficha App Store / Play | Disclaimer corto como **primera línea** de la descripción + subtítulo | Sí |
| Pantalla principal | Badge persistente (1.2) con etiqueta semántica | Sí |
| Ficha de cada fecha | Atribución de fuente (sección 3) + estado de la fecha | Sí |
| Panel de Fuentes/Criterios | Atribución completa + enlace a fuente MEF + modelo "solo fuente pública" | Sí |
| Acerca de | Disclaimer largo (1.3) como heading semántico | Sí |
| Notificaciones locales | Prefijo con nombre de la app + encuadre "recordatorio" (ver sección 5 de textos UI) | Sí |
| Widget Android | Nombre de la app visible + "no oficial" donde quepa | Sí |
| Landing web + footer | Disclaimer corto + enlace a repo open source + enlace a fuente MEF | Sí |

---

## 2. Pantalla "Acerca de" (contenido completo)

**Título de pantalla (heading 1):** App independiente y no oficial

**Bloque 1 — Qué es**
> *¿Cuándo Pagan?* es un proyecto independiente, gratuito y de código abierto que te muestra de forma rápida y clara las fechas de pago del sector público de Panamá: jubilados, gastos de representación y grupos 1, 2 y 3.

**Bloque 2 — Qué NO es**
> No es una app oficial del Gobierno de Panamá. No está afiliada, patrocinada ni avalada por el Ministerio de Economía y Finanzas (MEF) ni por ninguna entidad del Estado. No tramita ni resuelve pagos: para eso, contacta a tu entidad o al MEF.

**Bloque 3 — De dónde salen las fechas**
> Las fechas se transcriben de las publicaciones públicas del MEF. Solo mostramos lo ya publicado; los períodos que el MEF aún no publica aparecen como **Pendiente**. Cada fecha muestra su estado (Publicada, Modificada o Desactualizada) para que sepas qué tan vigente está.
> **Ver en la fuente oficial (MEF) →** *(enlace al calendario público del MEF)*
> Ante cualquier diferencia, prevalece la fuente oficial del MEF.

**Bloque 4 — Privacidad**
> No pedimos cuenta ni datos personales. No recolectamos ni compartimos información. Todo se queda en tu dispositivo. *(Ver Política de Privacidad →)*

**Bloque 5 — Código abierto**
> El código y los datos son públicos y auditables. Puedes ver exactamente cómo funciona y de dónde sale cada fecha.
> **Repositorio: [URL del repositorio]**

**Bloque 6 — Contacto**
> Este NO es un canal oficial del Gobierno. Nunca te pediremos cédula, número de cuenta bancaria ni datos personales. Para reportar un error o sugerencia: **[correo de contacto] · [URL de issues]**

**Bloque 7 — Aviso final**
> Recuerda: esta es una herramienta informativa independiente. La información oficial y vinculante siempre es la del Ministerio de Economía y Finanzas (MEF) de Panamá. El contador depende de la hora configurada en tu dispositivo.

---

## 3. Frase de atribución de la fuente (MEF como fuente pública)

**Estándar (panel de fuentes / detalle):**
> **Fuente: publicaciones públicas del Ministerio de Economía y Finanzas (MEF). App no afiliada al MEF.**

**Compacta (chip de ficha de fecha):**
> **Fuente pública: MEF · App no oficial**

**Con verificación (recomendada en pantalla de detalle):**
> **Fuente pública: MEF — [Ver en la fuente oficial] · App no oficial**

**Lista negra de atribución (PROHIBIDO en todo el copy):** "en colaboración con el MEF", "autorizado por", "avalado por", "provisto por el MEF", "powered by MEF", "en alianza con", "datos oficiales del MEF en tu bolsillo". El MEF se nombra **solo** para decir *de dónde salió el dato*, nunca *quién avala la app*.

---

## 4. Política de Privacidad (texto completo, listo para publicar)

> **Política de Privacidad — *¿Cuándo Pagan?***
> Vigente desde: [fecha] · Última actualización: [fecha]

**1. Quiénes somos.** *¿Cuándo Pagan?* es una aplicación **independiente, gratuita y de código abierto** que muestra fechas de pago publicadas por fuentes públicas del sector público de Panamá. **No es una aplicación oficial del Gobierno de Panamá ni del Ministerio de Economía y Finanzas (MEF).** El MEF se cita únicamente como fuente pública de la información. Responsable del proyecto: [mantenedor/organización]. Contacto: [correo] · Reportes: [URL del repositorio/issues].

**2. Nuestro principio: no recolectamos tus datos.** La app funciona 100% en tu dispositivo. No necesitas crear una cuenta. No pedimos tu nombre, cédula, teléfono, correo ni ningún dato personal. No tenemos servidores donde se guarde información tuya. No usamos publicidad, rastreadores ni perfiles de usuario.

**3. Qué se guarda en tu dispositivo (y solo ahí).** Para que la app sea útil sin conexión, guarda localmente: tu institución o grupo favorito (si eliges marcarlo); tus preferencias de recordatorio (si activaste avisos, con cuánta anticipación y a qué hora); tus preferencias de la app (modo oscuro, si ya viste la introducción); y una copia (caché) del calendario descargado. **Esta información nunca sale de tu dispositivo, no se nos envía ni a terceros, y no está asociada a tu identidad.** Puedes borrarla cuando quieras desde los ajustes del sistema (borrar datos / desinstalar).

**4. Conexión a internet.** La app se conecta a nuestro servicio de distribución para descargar y actualizar el calendario (datos públicos). En esa conexión **no se envía ningún dato personal tuyo**. Como en toda conexión a internet, el proveedor de infraestructura **Cloudflare, Inc.** (que aloja y entrega el archivo) procesa de forma técnica y temporal tu dirección IP y datos estándar de la solicitud, con el único fin de entregar el contenido y proteger el servicio; no usamos esa información para identificarte ni crear perfiles. No usamos cookies ni identificadores de seguimiento. El identificador de versión (ETag) es **el mismo para todas las personas** y no sirve para rastrearte.

**5. Notificaciones.** Los recordatorios se generan y programan **localmente** en tu dispositivo; no pasan por ningún servidor. Si los activas, la app te pedirá permiso para mostrar notificaciones. Puedes desactivarlos cuando quieras.

**6. Permisos.** *Notificaciones* (Android e iOS): para avisarte de las próximas fechas de pago; solo se pide si activas los recordatorios. *Acceso a internet*: para descargar y actualizar el calendario. *Reinicio del dispositivo* (Android): para reprogramar tus recordatorios tras reiniciar el teléfono. **No pedimos** ubicación, contactos, cámara, micrófono, archivos personales ni tu identidad.

**7. Menores de edad.** La app no está dirigida específicamente a menores y no recolecta datos de ninguna persona.

**8. Terceros.** *Cloudflare, Inc.*: aloja y entrega el calendario (ver punto 4). *Tiendas (Google Play, App Store)*: si descargas desde ellas, recolectan sus propias estadísticas conforme a sus políticas, fuera de nuestro control. No compartimos ni vendemos datos personales, porque no los recolectamos.

**9. Seguridad.** La descarga del calendario usa conexión cifrada (HTTPS/TLS). Tus preferencias permanecen en el almacenamiento de tu dispositivo.

**10. Tus derechos (Ley 81 de 2019, Panamá).** La Ley 81 de 2019 reconoce derechos de acceso, rectificación, cancelación, oposición y portabilidad (ARCO). Como no recolectamos ni almacenamos datos personales en servidores, no existe una base de datos tuya que consultar, corregir o eliminar; tú controlas tu información directamente en tu dispositivo. Ante dudas, escríbenos a [correo]. La autoridad competente en Panamá es la **Autoridad Nacional de Transparencia y Acceso a la Información (ANTAI)**.

**11. Código abierto.** El código de la app y del servicio es público: [URL]. Puedes auditar exactamente qué datos se usan y cómo.

**12. Cambios.** Si cambiamos esta política (por ejemplo, si añadimos una función con datos), lo indicaremos aquí y actualizaremos la fecha. Cualquier recolección futura será informada de forma clara y, cuando corresponda, **opcional**.

**13. Contacto.** [correo] · [URL de issues]

> **Publicación:** la política debe estar en una URL estable (recomendado GitHub Pages o Cloudflare Pages, p. ej. `cuandopagan.app/privacidad`) **antes** de crear las fichas de tienda, y embeberse también en "Acerca de". Ambas tiendas exigen URL de política aunque no se recolecten datos.

---

## 5. Respuestas para tiendas (Data Safety + Apple Privacy)

### 5.1 Google Play — Data Safety

| Pregunta | Respuesta |
|---|---|
| ¿La app recolecta o comparte datos de usuario? | **No.** Esta app no recolecta ni comparte datos de usuario. |
| Tipos de datos a declarar | **Ninguno.** |
| ¿Datos cifrados en tránsito? | **Sí** (la descarga del dataset usa HTTPS). |
| ¿Ofreces forma de solicitar eliminación de datos? | **No aplica.** El usuario borra todos los datos locales limpiando el almacenamiento o desinstalando; no hay datos del lado del servidor. |
| ¿Usa Advertising ID? | **No** (se remueve vía `tools:node="remove"`). |
| ¿Comprometido con la Política de Familias? | **No** (audiencia general). |

**Justificación interna (si Play lo cuestiona):** los datos viven solo en el dispositivo (no se transmiten); el único egreso de red son solicitudes anónimas para obtener un archivo público; la IP la procesa Cloudflare como **proveedor de servicio/CDN** para entregar contenido y seguridad, lo que califica como no-recolección por el desarrollador.

### 5.2 Apple — App Privacy ("Nutrition Labels")

- **App Store Connect > App Privacy:** seleccionar **"Data Not Collected"** (ningún dato recolectado por nosotros ni por SDKs de terceros).
- **App Tracking Transparency (ATT):** N/A — no hay tracking ni IDFA; no se enlaza `ATTrackingManager`.

**`ios/Runner/PrivacyInfo.xcprivacy` (incluir en el binario):**
```xml
<dict>
  <key>NSPrivacyTracking</key><false/>
  <key>NSPrivacyTrackingDomains</key><array/>
  <key>NSPrivacyCollectedDataTypes</key><array/>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
    <!-- Añadir FileTimestamp (C617.1/DDA9.1) y DiskSpace (E174.1) solo si
         path_provider / flutter_local_notifications lo requieren -->
  </array>
</dict>
```
Verificar que `shared_preferences`, `path_provider`, `flutter_local_notifications` y `home_widget` traigan su propio `PrivacyInfo.xcprivacy`. **No** enlazar `AppTrackingTransparency` ni `AdSupport`.

### 5.3 Invariante de gobernanza (protege ambas etiquetas)
Declaración "sin datos" sostenible **solo** si v1 no integra ningún SDK de analítica/crash/ads. Check de CI que rechace dependencias prohibidas: `firebase_analytics`, `firebase_crashlytics`, `sentry_flutter`, `amplitude`, `google_mobile_ads`, `appsflyer`, `facebook_*`, uso de `AdvertisingIdClient` / `ATTrackingManager`. PR checklist: "toca red/datos → actualizar política + etiquetas de tienda ANTES de merge". AndroidManifest debe incluir `<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>`.

---

## 6. Ficha de Google Play (deliberadamente NO oficial)

**Título (≤30):** `¿Cuándo Pagan? Panamá`

**Descripción breve (≤80):** `Fechas de pago del sector público de Panamá. App independiente, no oficial.`

**Descripción larga (≤4000):**
```
AVISO IMPORTANTE — App independiente y NO oficial. «¿Cuándo Pagan?» no está
afiliada al Gobierno de Panamá, al Ministerio de Economía y Finanzas (MEF) ni a
ninguna entidad pública. No es un producto oficial del Estado y no lo representa.
Es un proyecto independiente y de código abierto, hecho para consultar más fácil
la información que el MEF ya publica de forma pública.

«¿Cuándo Pagan?» te dice de manera rápida y clara cuándo toca el pago de salarios
del sector público panameño, según el calendario publicado por el MEF.

QUÉ PUEDES HACER
• Ver tu próximo pago con cuenta regresiva.
• Marcar "mi institución" como favorita (por ejemplo, MIDES) y ver de una sus fechas.
• Consultar el calendario anual completo por categoría: jubilados, gastos de
  representación y grupos 1, 2 y 3.
• Activar recordatorios locales antes de cada fecha. Las notificaciones funcionan
  en tu teléfono, sin crear cuenta.
• Usar la app sin internet: guarda la última información y te avisa cuando hay una
  versión más reciente.
• Widget en tu pantalla de inicio con el próximo pago siempre a la vista.
• Modo oscuro.

DE DÓNDE SALEN LAS FECHAS
Las fechas se transcriben de la fuente pública del MEF. Solo mostramos fechas ya
publicadas oficialmente; los períodos que el MEF aún no publica aparecen como
"Pendiente". Cada fecha muestra su estado (publicada, modificada o desactualizada)
para que sepas qué tan vigente está. Verifica siempre en la fuente oficial del MEF
antes de tomar decisiones.

PRIVACIDAD
No pedimos cuenta ni datos personales. No recolectamos ni compartimos información.
Todo se queda en tu dispositivo.

CÓDIGO ABIERTO
El código y los datos son públicos y auditables: [enlace al repositorio].

Recuerda: esta es una herramienta informativa independiente. La información oficial
y vinculante siempre es la del Ministerio de Economía y Finanzas (MEF) de Panamá.
```

**Novedades / What's new (v1):**
```
Primera versión: próximo pago con cuenta regresiva, calendario anual, recordatorios
locales, favorito "mi institución", modo oscuro y widget. App independiente, no oficial.
```

**Metadata equivalente App Store:**
- **Nombre (≤30):** `¿Cuándo Pagan? Panamá`
- **Subtítulo (≤30):** `Pagos públicos · no oficial`
- **Texto promocional (≤170):** `App independiente y no oficial para consultar las fechas de pago del sector público de Panamá según la fuente pública del MEF. Sin cuentas y sin recolección de datos.`
- **Keywords (≤100, sin marcas de gobierno):** `pago,quincena,planilla,sector publico,jubilados,salario,estatal,fechas,recordatorio,pension`
- **Descripción:** reutilizar la larga de Play, empezando por el AVISO IMPORTANTE.

**Notas para el revisor (Apple):**
```
Esta es una app informativa independiente y de código abierto. NO está afiliada al
Gobierno de Panamá ni al MEF. Solo muestra fechas de pago del sector público que el
MEF ya ha publicado de forma pública; las transcribe para consultarlas más fácil. La
app NO gestiona pagos, NO provee servicios gubernamentales y NO solicita datos
personales ni crea cuentas. Todo es local en el dispositivo. El disclaimer de
no-afiliación está visible en la ficha, en la pantalla de inicio y en "Acerca de".
Repositorio público: [enlace].
```
*(Categoría: Google Play = Tools; App Store = Utilities. NUNCA News ni Finance. Content rating: Para todos / 4+. Developer name independiente — nunca "MEF", "Gobierno", "Panamá Oficial".)*

---

## 7. Checklist de cumplimiento (casillas)

### 7.1 Google Play
- [ ] Nombre de desarrollador independiente (no "MEF", "Gobierno", "Panamá Oficial").
- [ ] Título `¿Cuándo Pagan? Panamá` sin sugerir oficialidad.
- [ ] Ícono editorial propio: SIN escudo, SIN bandera-como-identidad, SIN logos institucionales.
- [ ] Feature graphic 1024×500 sin elementos gubernamentales.
- [ ] Primer screenshot con overlay "App independiente · No oficial".
- [ ] Descripción larga abre con el disclaimer de no-afiliación (línea 1).
- [ ] "MEF" aparece solo como "fuente pública", nunca como reclamo de oficialidad.
- [ ] Categoría = Tools (NO News, NO Finance).
- [ ] URL de Política de Privacidad publicada y pegada en Play Console.
- [ ] Data Safety = "No se recolectan ni comparten datos"; cifrado en tránsito = Sí.
- [ ] `AD_ID` removido; sin analytics, sin FCM, sin SDK de terceros.
- [ ] POST_NOTIFICATIONS en runtime con contexto; NO declarar USE_EXACT_ALARM.
- [ ] Content rating IARC → Para todos / 3+.
- [ ] Prueba cerrada con 20 testers × 14 días (cuenta personal nueva) planificada.

### 7.2 App Store
- [ ] Nombre (≤30) y subtítulo con "no oficial".
- [ ] Keywords SIN "MEF"/"gobierno".
- [ ] Screenshots reales con disclaimer en el primero; sin logos institucionales.
- [ ] Notas al revisor (app informativa, open source, solo datos públicos del MEF).
- [ ] Disclaimer visible dentro de la app (banner + Acerca de).
- [ ] URL de Política de Privacidad.
- [ ] App Privacy = "Data Not Collected"; ATT = N/A.
- [ ] `PrivacyInfo.xcprivacy` presente con tracking=false y tipos vacíos.
- [ ] Funciones nativas evidentes (widget si aplica, notificaciones locales, cache offline, favorito, contador) para evitar rechazo 4.2.
- [ ] Age rating 4+; "Acceso web sin restricciones = No".

### 7.3 Web / PWA (Cloudflare Pages)
- [ ] Landing HTML estática en `/` (SEO + disclaimer indexable) + PWA Flutter en `/app`.
- [ ] HTTPS obligatorio; dominio neutral (NO gob.pa).
- [ ] `manifest.json` con description "no oficial"; `robots.txt` + `sitemap.xml`.
- [ ] Meta title/description, Open Graph y JSON-LD `WebApplication` (NO `GovernmentService`).
- [ ] `_headers` con CSP y cabeceras de seguridad; self-host total (sin Google Fonts remoto, sin tags de analítica, sin beacons).
- [ ] `/privacidad` y `/fuentes` publicadas antes de enviar a tiendas.
- [ ] Notificaciones web = "mejor esfuerzo" o deshabilitadas (sin push backend).

### 7.4 Legal / confusión-oficialidad
- [ ] Cero Escudo Nacional, Bandera, estrella patria, tricolor en disposición de bandera o marca país "Panamá" como identidad.
- [ ] Disclaimer presente en las 9 superficies de la matriz (sección 1.4).
- [ ] Atribución "Fuente pública: MEF" junto a CADA fecha + enlace "Ver en la fuente oficial".
- [ ] Lista negra de verbos de relación verificada en todo el microcopy.
- [ ] Copy encuadrado en "consultar fechas", nunca "consulta/recibe tu pago" ni "trámite".
- [ ] Notificaciones y widget con nombre de la app como prefijo y marca "no oficial".
- [ ] Regla del estado "Estimada" (Fase 2) documentada: rotular "Estimación de la app — no oficial".
- [ ] Búsqueda de colisión de nombre/marca en ambas tiendas y registro de marcas de Panamá.
- [ ] Revisión por abogado panameño de las citas (símbolos de la Nación, Ley 45/2007 ACODECO, Ley 35/1996) — aquí van como orientación, no dictamen.

### 7.5 Accesibilidad (a11y)
- [ ] Disclaimer "no oficial" en el árbol de Semantics y como heading en Acerca de, en TODAS las pantallas (no solo badge visual).
- [ ] Los 5 estados de fecha = icono (forma única) + etiqueta + color; distinguibles en escala de grises.
- [ ] Contraste verificado por token: texto esencial ≥4.5:1; texto grande/iconos/bordes ≥3:1 (dark y light).
- [ ] Texto del cuerpo escala hasta ≥200% sin recorte; solo el token "display/hero" se clampa (máx ~1.3×).
- [ ] Contador sin live-region por segundo; resumen "Faltan N días" para lector de pantalla.
- [ ] Touch target ≥48dp en todo control, incluidas celdas de calendario.
- [ ] Focus visible ≥2px con 3:1, no tapado por banner/nav.
- [ ] `prefers-reduced-motion` / `disableAnimations` respetado (odómetro, confeti, transiciones estáticos).
- [ ] Recorrido con TalkBack, VoiceOver (iOS) y VoiceOver+Safari / NVDA+Chrome (web).
- [ ] Fechas/horas vía `intl` locale `es`; días restantes en America/Panamá (UTC-5).

---

## 8. Recomendación de NOMBRE

**Recomendado: ¿Cuándo Pagan?** — Es literalmente la pregunta que el ciudadano hace y busca; usa cero vocabulario institucional; y su voz interrogativa en primera persona ciudadana es estructuralmente lo opuesto a un comunicado del Estado (el artefacto oficial real se llama "Calendario de Pago del Sector Público"). Es la mejor defensa de naming contra el riesgo ALTO de parecer oficial, y ya es el título de trabajo (cero reaprendizaje).

### Tabla de candidatos

| Nombre | Idea / significado | Seguro porque | Riesgo |
|---|---|---|---|
| **¿Cuándo Pagan?** *(recomendado)* | La pregunta literal del ciudadano = la consulta núcleo de la app. | Voz interrogativa: un Gobierno nunca nombra una herramienta con una pregunta. Cero palabras institucionales. | Descriptivo → marca denominativa débil; signos ¿ ? rompen en tiendas/URL; cuidar deriva a "Cuánto". |
| **¿Cuándo Cobro?** | Misma pregunta desde quien recibe; "cobrar" validado por jubilados. | Primera persona ciudadana; ideal para pensionados. | "Cobro" también = cargo/cobranza; algo más estrecho que "pagan". |
| **Quincena** *(estilizado "Quincena.")* | La palabra-ícono del día de pago en Panamá. | Sustantivo común, sin vínculo gubernamental; wordmark premium de una palabra. | Genérico → difícil de poseer; payroll/fintech podrían usarlo. |
| **La Quince** | Slang de la quincena ("ya viene la quince"). | Registro de calle, inequívocamente ciudadano. | "Quince" = 15 → no evoca la quincena de fin de mes; eco "quinceañera". |
| **Cae la Quincena** *(mark corto: ¿Ya Cae?)* | "Cae" = cuando el dinero aterriza. | 100% coloquial, anti-institucional. | Muy informal; puede percibirse poco premium para jubilados. |
| **Día Q** | Coinage: "Q" de quincena. | Abstracto, ownable, sin referencia institucional ni de bandera. | Significado no evidente; eco "Día D"; puede sonar a startup genérica. |

**Descartados explícitamente:** *Plata* (colisión directa con Banco Plata, banco digital MX), *Día de Pago* y *Calendario de Pago* (registro institucional → chocan con el título oficial del MEF y disparan el riesgo de afiliación).

**Aplicación del nombre:**
- Marca / wordmark: **¿Cuándo Pagan?**
- Tiendas, dominio y handles (sin signos): **Cuándo Pagan** → `cuandopagan.app` / `.pa` / `.org`, `@cuandopagan`
- Logomark: el signo de apertura **"¿"** invertido, en lima `#C6F647` sobre casi-negro (es del español, es una pregunta y no un sello/escudo, es ownable y refuerza el no-oficialismo).
- Respaldo de una palabra: **Quincena** (o `miQuincena`).

**Tagline principal:** *Mira cuándo cae tu quincena.*
**Lockup-disclaimer (siempre junto al wordmark):** *App independiente · No oficial · Fechas de fuente pública (MEF)*
**Alternativas:** "Tu quincena, sin sorpresas." · "La fecha de pago, antes de que la busques."

---

## 9. Prompts para imágenes con IA

> **Reglas transversales para los 3 (obligatorias):** estética editorial audaz, civic-tech/fintech premium, dark-mode-first. Paleta: fondo casi-negro `#0B0B0C`, crema cálido `#F7F5F0`, **un solo** acento lima eléctrica `#C6F647` (chartreuse). Acento secundario opcional muy limitado: marigold `#F2B441`.
> **EVITAR SIEMPRE (en los tres):** escudo de Panamá, bandera o tricolor rojo/azul/blanco en disposición de bandera, estrella patria, marca país "Panamá", cualquier sello/papelería oficial o estética `.gob.pa`; morado de Material 3 / look "app de IA genérica"; gradientes mesh/blob, glassmorphism, glow, sombras difusas; emojis; stock 3D plástico; personas reales reconocibles; logos de bancos o de gobierno. Texto legible y bien formado si aparece; alto contraste WCAG.

### 9.1 Ícono de la app
```
Ícono de app minimalista y editorial para "¿Cuándo Pagan?". Elemento central: un
signo de interrogación de apertura del español "¿" invertido, tipográfico, grueso y
geométrico, en color lima eléctrica chartreuse (#C6F647) sobre fondo sólido casi-negro
neutro (#0B0B0C). Estilo flat, bordes nítidos, alto contraste, sensación premium y
distintiva, anti-Material. Composición centrada, legible a 48px, con safe-area para
máscara redondeada/maskable. Una sola figura, cero ruido. Opcional: un sutil punto o
acento que insinúe "cuenta regresiva" sin convertirse en reloj literal.
EVITAR: escudo, bandera, tricolor, calendario realista, monedas detalladas, degradados,
sombras, morado, estética gubernamental.
```

### 9.2 Imagen de feature / hero (feature graphic 1024×500 y hero web)
```
Banner editorial horizontal para una app cívica independiente de fechas de pago. Fondo
casi-negro neutro (#0B0B0C) con mucho aire. Pieza central tipo PÓSTER: un bloque
rectangular lima eléctrica (#C6F647) con una fecha grande en tinta negra (ej. un número
"23" enorme tipo serif editorial expresivo) y debajo, en grotesca técnica, "Faltan 27
días". A un lado, texto crema (#F7F5F0) jerárquico, alineado a la izquierda, asimetría
intencional. Incluir de forma visible y pequeña la etiqueta "App independiente · No
oficial". Iluminación plana, look fílmico/premium, fintech serio. Sin movimiento, sin
brillos.
EVITAR: bandera/escudo/colores de bandera, logos institucionales, morado M3, gradientes,
glassmorphism, card soup uniforme, todo centrado, stock 3D, personas.
```

### 9.3 Ilustración de estado vacío
```
Ilustración de estado vacío, minimalista y de línea, para cuando el usuario aún no ha
elegido su institución (o cuando el período está "Pendiente"). Fondo casi-negro
(#0B0B0C). Motivo: un signo "¿" de línea fina crema (#F7F5F0) o una hoja de calendario
abstracta y vacía, con un único acento lima (#C6F647) — por ejemplo un círculo o marca
señalando un día. Mucho espacio negativo, trazo consistente (~1.75px), sereno y amable,
no alarmante (transmite "espera", no "error"). Estética editorial coherente con un
sistema de íconos de línea (estilo Phosphor/Lucide).
EVITAR: caras tristes, iconos de error rojos, bandera/escudo, monedas o billetes
realistas, gradientes, sombras difusas, morado, emojis, look corporativo genérico.
```

---

*Nota de cierre para el equipo: todo lo anterior se trata como **requisito de release, no "nice to have"**. Ninguna pantalla, push, widget o captura de tienda se aprueba sin su atribución/badge correspondiente. Las citas legales (símbolos de la Nación, Ley 45 de 2007 ACODECO, Ley 35 de 1996, políticas vigentes de Apple/Google) van como orientación y deben confirmarse con un abogado panameño y contra el texto VIGENTE de cada tienda antes de enviar.*


---

# Anexo — Registro de revisión adversaria (trazabilidad)

> Hallazgos crudos de los dos revisores. Las correcciones derivadas ya están en **§0.1 (vinculante)**; aquí se conservan para auditoría.

### Revisor 1 — Accesibilidad y completitud

**Veredicto:** aprobado-con-cambios — spec ambiciosa, completa en estructura y muy fuerte en legal/anti-oficialidad; pero tiene fallas de contraste reales en light mode, un agujero de foco lima-sobre-lima, y desconexiones entre el spec y el dataset real (MIDES/siglas, XIII/Aproximada) que rompen casos núcleo.

#### Problemas
- **[ALTA] a11y / contraste (light mode, estados)** — Dos colores de estado declarados NO cumplen el propio 'floor a11y ≥4.5:1 etiqueta/fondo' del spec (§4 'Decisión de conflicto a11y vs visual' y §5.1). Calculé sobre los tokens reales: (1) state.modified light #9A6400 sobre surface.2 #F4F1EA (token declarado para chips) = 4.44:1 → FALLA por poco; (2) la precisión 'Aproximada' (XIII) usa marigold como color de etiqueta y la tabla §4 NO da variante light (solo lista '#F2B441 (marigold)'). La única marigold de light disponible (accent.secondary light #C8881F) como texto da 2.66:1 sobre #F4F1EA y 3.00:1 sobre blanco → FALLA fuerte. La nota de cierre #5 dice 'lint/test rompe el build si un par texto cae bajo 4.5:1', así que la paleta declarada es internamente inconsistente con su propia regla.  
  → *Subir state.modified light a ~#8A5A00 (verificar ≥4.5 sobre #F4F1EA) y AÑADIR a la fila de precisión 'Aproximada' una variante light segura como texto (p.ej. ~#8A5A00/#7A5200; marigold queda solo como FONDO con tinta, nunca como label en light). Incluir estos dos pares en el golden/lint de contraste.*
- **[ALTA] a11y / foco (WCAG 2.4.11/2.4.13)** — El anillo de foco es lima accent.primary (§5.3) y su contraste solo está validado 'sobre canvas' (8.5:1). Pero la CardProximoPago en estado Publicada se vuelve 'póster lima' (fill lima sólido, §3.1/§4/§6). Si esa card —o cualquier control dentro/sobre ella, incl. 'cambiar institución'— recibe foco, el anillo lima sobre superficie lima da ~1:1 → foco INVISIBLE en la superficie más importante de la app. El spec nunca define el indicador de foco sobre superficies lima/marigold.  
  → *Definir un token de foco de contraste garantizado sobre lima (anillo oscuro #0B0B0C o doble-anillo tinta+claro) y exigir ≥3:1 contra la superficie adyacente real, no solo contra canvas. Agregar al golden de foco un caso 'control enfocado sobre póster lima'.*
- **[ALTA] datos / buscador (caso núcleo)** — El ejemplo rector 'MIDES → GRUPO 3' (§3.2, modelo Entidad, ficha Play) NO funciona con el dataset real: grupos_entidades.json no tiene siglas; la entidad es 'Min. de Desarrollo Social' y el modelo Entidad solo tiene {nombre, grupo} (sin campo siglas/alias). El BuscadorInstitucion 'filtra por entidad o grupo' (§3.2), así que escribir 'MIDES' (o 'MEDUCA', 'MINSA', 'MOP', 'MEF') no devuelve nada. Es la consulta núcleo del producto y el ejemplo que se repite en todo el spec.  
  → *Especificar una tabla de siglas/alias (MIDES, MEDUCA, MINSA…) como capa de la app (no está en la fuente MEF), añadir campo `siglas: List<String>` a Entidad y normalización de búsqueda. Definir de dónde sale ese mapa (curado en repo, auditable) sin romper el 'verbatim' del dato de fecha.*
- **[MEDIA] datos / XIII Mes (feature aseverada sin cableado)** — El spec trata 'Aproximada/XIII' como feature viva de v1 (§3.4 'precisión Aproximada para XIII', §4 fila precision, §3.6 Fuentes explica 'Aproximada', Acerca de Bloque 3). Pero en el dataset real xiii_mes.json es una tabla aparte {anio, semestre, mes, fecha_aprox} de 3 filas, SIN categoria/quincena/fecha_pago, y calendario.json NO tiene campo precision. En el dominio NO hay entidad XiiiMes, ni DAO, ni pantalla que muestre esas 3 fechas; Precision.aproximada solo existe como atributo de EntradaCalendario que nunca se setea desde el wire. Resultado: igual que 'Estimada', la precisión 'Aproximada' es de facto inalcanzable en v1, contradiciendo que se presenta como activa.  
  → *O (a) declarar XIII/Aproximada también DORMIDO en v1 (como Estimada) y quitarlo de pantallas, o (b) añadir entidad XiiiMes + query + sección UI (en Calendario o Detalle) que consuma xiii_mes.json y marque Precision.aproximada. Decidir y reflejarlo en §3, §4 y modelos.*
- **[MEDIA] a11y / tipografía dinámica (contradicción interna)** — ContadorRegresivo: §5.3 y §6 exigen 'ancho fijo reservado' para el número del contador, pero countdown.num mapea a headlineLarge (no a la familia display), y la regla a11y §5.2 dice que 'headline/title/body/label SIN tope, soportan ≥200% sin clipping' (solo display/hero se clampa a 1.3×). Ancho fijo + escalado sin tope al 200% (44px→~88px, figuras tabulares) = recorte/overflow del número. La regla de ancho fijo y la regla de escalado uncapped chocan.  
  → *Permitir que el contenedor del contador crezca con textScaler (min-width reservado, no width fijo) o clampar explícitamente countdown.num (declararlo en la excepción display con tope ~1.3×). Probar Home con textScaler 2.0 en golden.*
- **[MEDIA] a11y / disclaimer perceptible + touch target** — El ribbon 'no oficial' (omnipresente, Definition of Done) usa el token `micro` = 11px y la regla §5.2 solo exime de tope a display/hero y cubre escalado de headline/title/body/label, pero NO menciona micro/overline/caption. Riesgo: el disclaimer legal más visible queda a 11px y posiblemente sin escalar a 200%. Además es 'slim bar' tappable → Acerca de (§2/§6), lo que choca con el mínimo 48×48dp (§5.3): o la barra es slim (<48dp, falla target) o consume 48dp en TODAS las pantallas (contradice 'slim').  
  → *Garantizar que el texto del ribbon escale con textScaler (o subir a ≥12–13px y permitir wrap), y resolver el área táctil: hit-target de 48dp aunque el visual sea slim, documentando que no roba foco ni tapa contenido superior.*
- **[MEDIA] coherencia (3 secciones) / contador y zona horaria** — Contradicción directa: ARQ invariante #6 y PRODUCTO §5.4 dicen que todo 'hoy'/días restantes usa America/Panamá FIJO 'nunca la zona del dispositivo'. Pero Acerca de Bloque 7 y el disclaimer largo (CUMPLIMIENTO 1.3 implícito) dicen 'El contador depende de la hora configurada en tu dispositivo'. Confunde el reloj absoluto del dispositivo (sí se usa) con la zona horaria (fijada a Panamá). Tal como está, el copy legal contradice la regla técnica.  
  → *Unificar el copy: 'Las fechas y la cuenta atrás se calculan en hora de Panamá; solo dependen de que la fecha/hora de tu dispositivo esté correcta.' Eliminar 'la zona configurada en tu dispositivo'.*
- **[MEDIA] coherencia (3 secciones) / string y ubicación del disclaimer** — CUMPLIMIENTO dice que el copy 'se reutiliza literalmente, no se reescribe por pantalla', pero el disclaimer persistente aparece con 3 cadenas distintas: ribbon 'App independiente · No oficial' (PRODUCTO §2), badge 'No oficial · Proyecto independiente' (CUMPLIMIENTO 1.2 y ARQ disclaimer_badge.dart), y micro 'NO OFICIAL' (§5.2). Además PRODUCTO pone un RIBBON en TODAS las pantallas, mientras la matriz DoD (1.4) exige solo 'Badge persistente' en 'Pantalla principal' — y PRODUCTO lista Ribbon Y DisclaimerBadge como componentes separados. No queda claro qué elemento es el omnipresente ni con qué texto.  
  → *Fijar UNA cadena canónica y UN componente persistente (ribbon o badge), referenciado por las 3 secciones; alinear la matriz 1.4 (que diga 'todas las pantallas', no solo principal) con PRODUCTO §2.*
- **[MEDIA] posicionamiento / wording 'fuente pública' vs 'fuente oficial' (premisa sensible)** — La premisa 1 manda citar al MEF SOLO como 'fuente pública'. El chip canónico cumple ('Fuente pública: MEF'), pero el enlace de salida se llama repetidamente 'Ver en la fuente oficial (MEF)' (PRODUCTO §3.4/§3.6, ARQ, CUMPLIMIENTO 2/3) y se usa 'prevalece la fuente oficial del MEF'. Mezclar 'pública' y 'oficial' en la misma línea de atribución, en una app cuyo riesgo de parecer oficial es ALTO, es precisamente el matiz a cuidar.  
  → *Estandarizar a 'Ver en el sitio del MEF' o 'Ver en la fuente pública (MEF)'. Reservar 'oficial' solo para frases sobre el carácter vinculante del dato ('la información vinculante es la del MEF'), nunca como etiqueta del canal junto a la marca.*
- **[MEDIA] i18n / nombres de entidades (display y búsqueda)** — Los nombres en grupos_entidades.json vienen SIN tildes y abreviados ('Min. de Educacion', 'Contraloria General', 'Min. de Economia y Finanzas', 'Organo Judicial', 'Procuraduria...'). SeleccionEntidad.etiqueta = entidad.nombre (crudo), así que la UI editorial en 'español neutral panameño' mostrará texto sin acentos y abreviado. A diferencia de Categoria (que tiene wire→display), Entidad no tiene normalización de display ni búsqueda insensible a acentos. Choca con la dirección 'premium' y con el público de adultos mayores.  
  → *Añadir mapa de display para Entidad (tildes correctas y opción de expandir 'Min.'→'Ministerio de') y búsqueda normalizada (sin acentos, por siglas y por nombre).*
- **[BAJA] datos / estado 'Modificada' en instalaciones nuevas** — §4 y §5 (paso 5) presentan 'Modificada' como estado v1 con tratamiento UI, y prometen que instalaciones nuevas lo vean vía manifest.cambios. Verifiqué: manifest.json real NO trae `cambios` ni `semestres_meta`, y la nota de cierre de ARQ admite que emitirlos en el pipeline está 'sugerido — sin implementar'. Entonces, en v1, 'Modificada' solo es alcanzable por diff local (usuarios que ya tenían caché previa); un usuario nuevo nunca verá 'Modificada' aunque una fecha haya cambiado antes de instalar. El spec medio lo reconoce pero lo presenta como funcional.  
  → *Marcar explícitamente que en v1 'Modificada' es solo derivada por diff local (no para fresh installs) hasta que el pipeline emita el changelog, o bajar 'Modificada' a 'parcialmente activa' en §4.*

#### Huecos
- XIII Mes: la fuente tiene xiii_mes.json (3 fechas aprox.) pero NO hay entidad de dominio, ni DAO/query, ni pantalla que las muestre. Falta definir el consumidor de ese dato o declararlo dormido.
- Capa de siglas/alias de entidades (MIDES, MEDUCA, MINSA, MOP, MEF…) ausente: el campo no existe en la fuente ni en el modelo Entidad, y sin ella el buscador no resuelve el caso núcleo. Falta especificar el origen curado y el campo `siglas`.
- Normalización de display de entidades (tildes correctas, expandir 'Min.'→'Ministerio de') y búsqueda insensible a acentos: no especificadas (los datos llegan sin tildes y abreviados).
- Estados del Widget Android no cubiertos: el spec define el widget con favorito+fecha, pero NO define qué muestra sin favorito, en estado Pendiente/Desactualizada, ni antes del primer sync (las pantallas sí tienen empty states, el widget no).
- Set de copy de notificaciones incompleto: solo hay un ejemplo ('Una fecha de pago se acerca'). Faltan los textos exactos por tipo (víspera, día de pago, 'tu fecha cambió', 'se publicó nuevo período'), todos con prefijo de marca + encuadre 'no oficial' como exige la matriz 1.4.
- Variante de color light segura para la etiqueta 'Aproximada' (precisión): la tabla §4 omite la columna light para esa fila y la marigold disponible falla 4.5:1 como texto. Falta el token light.
- UX de errores duros sin telemetría: existe Resultado<T>/fallos tipados, pero no hay pantallas/estados para seed corrupto en primer arranque sin red, fallo de parseo del wire, o fallo de migración drift. Con Crashlytics/Sentry prohibidos, conviene UX de recuperación explícita.
- Assets visuales de tienda (screenshots): el checklist exige 'primer screenshot con overlay No oficial' y screenshots reales, pero no hay shot-list, captions ni tratamiento del overlay especificado (sí están los prompts de ícono, feature graphic y empty state).
- Control in-app de 'borrar mis datos / restablecer': la política delega el borrado al sistema operativo; Ajustes gestiona el favorito pero no ofrece un reset/borrado explícito dentro de la app (útil para review de Apple y para el usuario).
- Política de privacidad y Acerca de con placeholders sin rellenar ([fecha], [correo], [URL repo], [mantenedor], dominio): es una base sólida, pero debe poblarse y publicarse en URL estable ANTES de crear fichas de tienda (el propio spec lo nota).

### Revisor 2 — Legal / confusión / tiendas

## Veredicto
**Aprobado-con-cambios.** Blindaje anti-suplantación en UI muy sólido, pero hay un agujero de veracidad en "Data Safety / Data Not Collected", una contradicción "fuente pública vs. fuente oficial" que el propio spec se autoincumple, y riesgos de 4.2 (iOS) y de daño-al-consumidor subestimados.

## Problemas
- **[ALTA] Data Safety / Apple Privacy:** "No se recolectan datos" está asumido, no probado. El Worker es el endpoint PROPIO del desarrollador, no un CDN de un tercero; "no recolección" solo se sostiene si los datos son efímeros (sin loguear IP/headers). Nada prohíbe el logging del Worker (Cloudflare Logpush/analytics retienen request data por defecto). → Invariante de gobernanza: Worker sin Logpush ni logging de IP; analítica solo agregada; documentar "procesamiento efímero por proveedor de infraestructura"; check de CI/PR que falle si el Worker introduce logging. Sin esto la declaración es falsa = suspensión por Data Safety misrepresentation.
- **[ALTA] Contradicción "solo fuente pública":** el spec usa "fuente oficial" ~7 veces y "fechas oficiales de pago publicadas por el MEF" en el disclaimer largo, pese a que su propia lista negra prohíbe "datos oficiales del MEF". → Regla codificada: "oficial" solo puede modificar al CANAL/publicación/sitio del MEF, jamás a la app, sus datos, fechas o avisos. Cambiar §1.3 a "las fechas de pago que el MEF publica en sus canales oficiales". Añadir "datos/fechas oficiales (de la app)" a la lista negra.
- **[MEDIA] iOS 4.2 (funcionalidad mínima):** el widget —feature nativa estrella— no existe en iOS v1; queda notificaciones+caché+favorito+contador, leíble como "web". → Incluir en iOS v1 un widget WidgetKit mínimo o Live Activity de cuenta regresiva (home_widget soporta WidgetKit). No depender del widget Android para el alegato 4.2.
- **[MEDIA] iOS ITMS-91053 (required reason API):** PrivacyInfo solo declara UserDefaults; path_provider/drift/sqlite3/flutter_local_notifications tocan FS. → Declarar proactivamente FileTimestamp (C617.1/DDA9.1) y DiskSpace (E174.1); correr Privacy Report de Xcode antes de enviar.
- **[MEDIA] Aserciones en 2ª persona ("Te pagan hoy", "Tu fecha de pago cambió"):** personalizan e implican vínculo con tu pagador (riesgo de suplantación + daño al consumidor Ley 45/2007). → (1) push de cambio con atribución y encuadre neutro ("El MEF publicó un cambio en una fecha de pago — verifica en el sitio del MEF · no oficial"); (2) toda fecha aseverada (héroe/widget/push) co-ubica chip de estado + afford "verifica en la fuente"; (3) evaluar "Pago previsto: hoy, según MEF".
- **[MEDIA] Disclaimer solo en el 1er screenshot:** el resto del carrusel es el principal vector de "esto es del Gobierno". → Overlay "App independiente · No oficial" en TODOS los screenshots de ambas tiendas.
- **[MEDIA] SEO/Web:** no se fija el título indexable. Si la landing rankea para "calendario de pago MEF", el usuario llega creyendo que es oficial. → <title>, OG/Twitter title y H1 deben incluir "no oficial / independiente"; preferir .app sobre .org (.org connota institucional).
- **[BAJA-MEDIA] Onboarding "¿Y tú, dónde trabajas?":** socava no-afiliación y privacidad (enmarca como si conociera tu empleador). → Neutralizar a "Elige tu institución o grupo" / "¿Qué calendario te interesa?".
- **[BAJA] "El contador depende de la hora de tu dispositivo"** contradice "America/Panamá fijo". → "Los días restantes se calculan en hora de Panamá (UTC-5); requiere que el reloj de tu dispositivo esté correcto".
- **[BAJA] Parsing estricto vs "forward-compatible":** Categoria.fromWire/EstadoFecha sin orElse crashean ante un valor de wire nuevo. → orElse → default seguro (publicada/exacta) + log local; nunca crash.

## Huecos
- Plan de respuesta a takedown/queja (MEF/ACODECO/competidor reporta impersonation): protocolo + contacto + kill-switch.
- Mecanismo de dato disputado/corrección: una fecha errónea-pero-fresca se muestra "Publicada" (póster lima); falta expresar "publicada pero en revisión/disputada" y un canal de corrección más rápido que el bump de data_version.
- Verificación automatizada de la matriz DoD: golden/integration test que FALLE el build si una superficie pierde el string/Semantics "no oficial".
- Gate de revisión legal con dueño nombrado y fecha (no casilla suelta).
- "Panamá" en el título vs. prohibición de Marca País: nota explícita de que es alcance geográfico y jamás el logotipo/Marca País registrada.
- Disclaimer en notificación colapsada / canal Android nombrado "App no oficial".
- Keywords "estatal"/"sector publico": nota de que no empujen a Apple a re-bucketar como Finance/Government (documentar el par Tools/Utilities).
