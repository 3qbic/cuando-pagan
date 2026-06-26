# Arquitectura - App "¿Cuándo Pagan?" (Calendario de Pago Sector Público de Panamá)

Documento maestro del sistema. Cubre el pipeline de datos, el scraper del MEF, el
"API" de actualización y la app móvil. Audiencia: mantenedor del proyecto (Alexis García).

---

## 1. Objetivo

Que cualquier servidor público pueda abrir una app y saber **cuándo le pagan**, indicando
únicamente su institución. La data viene de los PDF que publica el MEF cada semestre; la
app debe mantenerse fresca **sin republicar el APK** cada vez que el MEF actualiza.

---

## 2. Visión general del flujo

```
   MEF (web, PDF semestrales)
            |
            v
   [1] scraper_mef.py  -- detecta semestres nuevos y baja los PDF
            |
            v
   [2] Extracción + transcripción a build_dataset.py (SOURCE OF TRUTH)
            |
            v
   [3] build_dataset.py  -- genera CSV + JSON + manifest.json (valida 60 filas/semestre)
            |
            v
   [4] Publicación estática (GitHub Pages / Supabase Storage)  <-- el "API"
            |
            v
   [5] App móvil (Flutter)  -- al abrir lee manifest.json; si hay version mayor, descarga
                               y reemplaza su base local (SQLite). Funciona offline.
```

El "API" no es un servidor: son **archivos JSON estáticos** en un hosting con CDN. Cero backend.

---

## 3. Modelo de datos

### 3.1 `calendario` (tabla principal, formato tidy)
1 fila por **año x semestre x mes x categoría x quincena**. 60 filas por semestre.

| Campo | Tipo | Ejemplo |
|-------|------|---------|
| `anio` | int | 2026 |
| `semestre` | int (1\|2) | 2 |
| `mes` / `mes_num` | str / int | JULIO / 7 |
| `categoria` | str | GRUPO 3 |
| `quincena` | int (1\|2) | 1 |
| `inicio_registro`, `cierre_registro`, `retencion_ach`, `fecha_pago` | fecha ISO | 2026-07-15 |

`categoria` ∈ { JUBILADOS, GASTOS DE REPRESENTACION, GRUPO 1, GRUPO 2, GRUPO 3 }.

### 3.2 `grupos_entidades` (leyenda Grupo → Entidad)
La columna "GRUPOS POR FECHA DE PAGO" del PDF. **Idéntica entre semestres**; cambia rara vez.
33 entidades. **MIDES (Min. de Desarrollo Social) = GRUPO 3.**

### 3.3 `xiii_mes` (Décimo Tercer Mes aprox.)
Fechas aproximadas: 20-feb, 06-ago, 04-dic de 2026.

### 3.4 Consulta núcleo ("¿cuándo pagan?")
```sql
SELECT c.mes, c.quincena, c.fecha_pago
FROM calendario c
JOIN grupos_entidades g ON g.grupo = c.categoria
WHERE g.entidad = :entidad_elegida
  AND c.fecha_pago >= current_date
ORDER BY c.fecha_pago;
```

---

## 4. Pipeline de datos (carpeta `pipeline/`)

| Archivo | Rol |
|---------|-----|
| `scraper_mef.py` | Detecta/descarga semestres nuevos del MEF |
| `build_dataset.py` | **Source of truth** de los datos + generador de CSV/JSON/manifest |
| `processed.json` | Registro de semestres ya procesados (lo usa el scraper) |
| `descargas/` | PDF bajados por el scraper (se crea al usar `--download`) |

### 4.1 Scraper (`scraper_mef.py`)
- Lee el HTML del MEF, extrae enlaces a PDF y su texto.
- **Asigna el año por el encabezado de sección de la página**, no por el nombre del archivo.
  - *Lección aprendida:* los PDF del 1er semestre se suben en diciembre del año anterior, así que
    la ruta `/wp-content/uploads/2025/12/...2026...pdf` engaña. Por eso el año se toma del
    encabezado (`<h2>2026</h2>`) y, como respaldo, del **nombre del archivo** (no de la carpeta).
- Compara contra `processed.json` y reporta lo NUEVO.
- **Exit code 10** si hay semestres pendientes → ideal para cron/CI que dispare un aviso.

Uso:
```bash
python pipeline/scraper_mef.py             # reporta qué hay nuevo
python pipeline/scraper_mef.py --download  # además baja los PDF pendientes
python pipeline/scraper_mef.py --all       # lista TODO lo publicado (2019–2026)
```
Probado contra la web real: detecta los 16 semestres (2019-S1 … 2026-S2).

### 4.2 Generador (`build_dataset.py`)
- Contiene los datos transcritos (DATOS, XIII, GRUPOS).
- **Valida** que cada semestre tenga exactamente 60 filas antes de publicar.
- Emite: CSV (raíz), JSON (`data/`) y `manifest.json`.

### 4.3 Limitación honesta: extracción del PDF
La transcripción de la tabla del PDF a `build_dataset.py` **hoy es manual/asistida**, porque el
layout es feo (celdas combinadas, columnas pegadas). El scraper automatiza *detectar y bajar*;
la *extracción estructurada* debe pasar el control de 60 filas antes de confiar en ella.
Para automatizarla más adelante: instalar `pdfplumber`/`camelot` y escribir un parser que
valide contra el conteo esperado, marcando para revisión manual si no cuadra.

---

## 5. El "API" de actualización (carpeta `data/`)

Lo que la app consume. Son archivos **estáticos**:

| Archivo | Contenido |
|---------|-----------|
| `manifest.json` | `data_version`, fecha, semestres incluidos, conteo, nombres de archivos |
| `calendario.json` | Array tidy completo (todas las filas) |
| `grupos_entidades.json` | Leyenda Grupo → Entidad |
| `xiii_mes.json` | Décimo tercer mes |

### 5.1 Mecánica de actualización (sin republicar APK)
1. La app trae una **copia semilla** de estos JSON (para funcionar al instalar, offline).
2. Al abrir, descarga **solo `manifest.json`** (pocos KB).
3. Compara `manifest.data_version` con la versión guardada localmente.
4. Si la remota es mayor → descarga `calendario.json` (+ grupos + xiii) y **reemplaza** la base local.
5. Si no hay internet → usa la base local. Nunca se queda sin responder.

> Subir datos nuevos = correr `build_dataset.py` (con `DATA_VERSION` +1) y **publicar la carpeta
> `data/`**. La app se actualiza sola en la próxima apertura. No se toca Google Play.

### 5.2 Dónde hospedar el "API": **Cloudflare Worker (free tier)** — elegido
Infra a costo **$0**. El Worker empaqueta los JSON y los sirve desde el borde (CDN global).

| Opción | Costo | Notas |
|--------|-------|-------|
| **Cloudflare Worker** | Gratis (100k req/día) | **Elegido.** Endpoint `/v1/version` ultraligero, ETag/304, CORS, y espacio para lógica futura (delta, push, auth) sin otro servidor. |
| Cloudflare Pages | Gratis | Aún más simple si fuera 100% estático, pero sin endpoint de lógica |
| GitHub Pages / repo raw | Gratis | Alternativa estática con CDN |
| Supabase Storage | Gratis | Útil si ya usas Supabase para auth (ver §7) |

#### Dimensionamiento (¿cabe en el free?)
| Límite free de Workers | Uso real | Veredicto |
|------------------------|----------|-----------|
| 100,000 req/día | 1 request liviano por apertura de app | Soporta ~100k aperturas/día |
| 10 ms CPU/request | Servir JSON estático <1 ms | Sobra |
| Tamaño bundle | API completa = **39.8 KiB / 3.66 KiB gzip** | Trivial |

#### Endpoints del Worker (`worker/src/index.js`)
| Ruta | Devuelve | Uso |
|------|----------|-----|
| `/v1/version` | `{data_version, fecha, semestres}` (~100 B) | **La app llama esto al abrir.** Cache 5 min |
| `/v1/all` | manifest + calendario + grupos + xiii (~27 KB) | UN solo request trae todo el dataset |
| `/v1/manifest` | manifest.json | Metadatos |
| `/v1/calendario` | array tidy completo | Datos principales |
| `/v1/grupos` `/v1/xiii` | leyenda / décimo tercer mes | Auxiliares |

- **CORS** abierto (GET/OPTIONS) para que la app consuma sin fricción.
- **ETag = `"v{data_version}"`**: si la app manda `If-None-Match` con su versión y no cambió → **304** (cero bytes de cuerpo). Ahorro de ancho de banda.
- Probado localmente (esbuild bundle + Node): rutas 200, 304 y 404 correctas, OPTIONS 204.

#### Desplegar el Worker
```bash
cd worker
npm install
python ../pipeline/build_dataset.py     # regenera worker/src/data/
npx wrangler deploy                      # publica (pide login la 1a vez: npx wrangler login)
# URL: https://calendario-pago-pa.<tu-subdominio>.workers.dev/v1/version
```
> Actualizar datos = `build_dataset.py` (con `DATA_VERSION` +1) + `wrangler deploy`. La app se
> refresca sola en la próxima apertura. Google Play no se toca.

### 5.3 ¿Quién dispara la verificación? — Cron Trigger + `/v1/status`
La verificación tiene **dos capas** (importante no confundirlas):

| Capa | Qué hace | Automatización |
|------|----------|----------------|
| **Detección** | Revisa el MEF y dice si hay un semestre nuevo | **Automática**: Cron Trigger del Worker, semanal |
| **Publicación** | Extraer tabla del PDF → validar 60 filas → `DATA_VERSION` +1 → deploy | **Humana** (el parseo del PDF requiere revisión; pasa solo ~2 veces/año) |

- **Disparador:** `[triggers] crons = ["0 12 * * 1"]` en `wrangler.toml` → cada **lunes 12:00 UTC** el
  Worker ejecuta su handler `scheduled`, que consulta el MEF (lógica en `worker/src/mef.js`, port del
  scraper) y, si hay KV, guarda el resultado.
- **Lectura:** `GET /v1/status` devuelve `{ checked_at, contabilizado, publicado_en_mef, nuevos, hay_nuevo }`.
  `?live=1` fuerza chequeo en vivo. **No hay notificación push**: tú consultas el endpoint cuando quieras.
- **Regla anti-falsos-positivos:** solo marca `nuevo` lo cronológicamente posterior al último semestre
  contabilizado (`LATEST_ACCOUNTED`). Por eso los 14 PDF históricos (2019–2025) no disparan alarma; sí lo hará 2027-S1.
- **KV es opcional:** sin KV, `/v1/status` hace el chequeo en vivo (cacheado 5 min). Con KV, sirve el
  último resultado del cron. Activarlo: `npx wrangler kv namespace create MEF_KV` y descomentar el bloque
  en `wrangler.toml`.
- Probado contra la web real: detecta los 16 semestres; con 2026 contabilizado, `hay_nuevo=false` (correcto).

Cuando `/v1/status` reporte `hay_nuevo: true`, se ejecuta el **runbook anual (§8)**.

---

## 6. App móvil

### 6.1 Recomendación de framework: **Flutter**
| Criterio | Flutter | React Native |
|----------|---------|--------------|
| Offline-first + SQLite | Excelente (`drift`/`sqflite`) | Bueno (`op-sqlite`/WatermelonDB) |
| Un solo APK Android | Sí | Sí |
| Curva si vienes de web/JS | Media (Dart) | Baja (JS/TS) |
| Tamaño/rendimiento | Muy bueno | Bueno |

**Sugerencia:** Flutter, por ser una app de datos offline-first sencilla orientada a Android.
Si tu equipo ya domina JavaScript/React, React Native es igual de válido. La arquitectura de
datos (JSON + manifest + SQLite local) es **idéntica** en ambos.

### 6.2 Almacenamiento local
- Empacar `calendario.json` como asset semilla.
- En el primer arranque, cargarlo a SQLite local (tablas `calendario`, `grupos_entidades`, `xiii_mes`).
- Guardar `data_version` local en preferencias.

### 6.3 Pantallas mínimas (MVP)
1. **Selección de institución** (lista desde `grupos_entidades`, con buscador).
2. **Próximos pagos** de esa institución (consulta núcleo §3.4): próxima fecha grande + lista.
3. (Opcional) Calendario mensual / detalle de quincenas y retención ACH.

### 6.4 Flujo de arranque (pseudocódigo)
```
onOpen():
  if primeraVez: cargarSemillaLocal()         // assets empacados en el APK
  try:
    v = GET /v1/version                        // ~100 bytes
    if v.data_version > localVersion:
        data = GET /v1/all                     // 1 request: manifest+calendario+grupos+xiii
        reemplazarSQLite(data); localVersion = v.data_version
  except sinInternet:
    seguir con datos locales                   // offline-first
  mostrarPantallaInstitucion()
```
Base URL: `https://calendario-pago-pa.<subdominio>.workers.dev`. La app guarda `localVersion`
en preferencias y opcionalmente manda `If-None-Match: "v{localVersion}"` para recibir 304.

---

## 7. ¿Hace falta Supabase?

| Necesidad | ¿Backend/Supabase? |
|-----------|--------------------|
| Saber cuándo pagan | **No.** Data pública, pequeña, igual para todos → JSON estático + SQLite local. |
| Login / registro de usuarios | Solo si vas a guardar algo del usuario |
| Notificación push "te pagan mañana" | Sí (Supabase + FCM, o servicio de push) |
| Guardar "mi institución" / favoritos | Local basta; Supabase solo si quieres sincronizar entre dispositivos |

**Plan recomendado por fases:**
- **Fase 1 (MVP):** 100% local + JSON estático. Sin login, sin costo, offline. Resuelve el 90%.
- **Fase 2:** Si quieres push de recordatorio o cuentas, agregar Supabase (auth + tabla de
  suscripciones + Edge Function que dispara push según `fecha_pago`). El free tier alcanza.

Importante: meter Supabase ahora **no** mejora la consulta de "cuándo pagan"; solo suma valor
cuando entren notificaciones o cuentas. Se puede añadir después sin rehacer la base local.

---

## 8. Runbook anual (cuando el MEF publique 2027)

1. `python pipeline/scraper_mef.py` → confirma "2027-S1 NUEVO".
2. `python pipeline/scraper_mef.py --download` → baja el PDF a `pipeline/descargas/`.
3. Abrir el PDF, transcribir/extraer la tabla y agregar el bloque del semestre a `DATOS` en
   `build_dataset.py` (y a `XIII`/`GRUPOS` si cambian). Revisar si la leyenda de grupos cambió.
4. Subir `DATA_VERSION` +1 y agregar la clave a `SEMESTRES`.
5. `python pipeline/build_dataset.py` → debe pasar la validación de 60 filas/semestre
   (también copia los JSON a `worker/src/data/`).
6. Desplegar: `cd worker && npx wrangler deploy`.
7. Agregar `"2027-S1"` a `pipeline/processed.json`.
8. La app se actualiza sola en la próxima apertura. (Solo se republica APK si cambia el código.)

> Automatización opcional: un cron (GitHub Actions/Task Scheduler) que corra el scraper
> semanal y, por el exit code 10, te envíe un correo "hay un semestre nuevo del MEF".

---

## 9. Estado actual

| Componente | Estado |
|------------|--------|
| Modelo de datos + CSV + DuckDB | Hecho (120 filas 2026) |
| JSON publicado + manifest.json | Hecho (`data/`, data_version=1) |
| Scraper del MEF (detección 2019–2026) | Hecho y probado |
| Validación 60 filas/semestre | Hecho |
| Cloudflare Worker (API) | Hecho y probado local (falta `wrangler deploy` con tu cuenta) |
| Verificación MEF: Cron Trigger + `/v1/status` | Hecho y probado (detección JS contra web real) |
| Extracción automática del PDF | Parcial (detección/descarga sí; parseo de tabla manual) |
| App móvil (Flutter) | Pendiente (diseño definido aquí) |
| Notificaciones push / auth | Fase 2 (opcional) |

---

## 10. Archivos del proyecto

```
calendario/
├─ ARQUITECTURA.md                 <- este documento
├─ README_calendario.md            <- guía rápida de los datos/consultas
├─ Calendario-...Primer-semestre-2026-003.pdf
├─ Calendario-...Segundo-semestre-2026.pdf
├─ calendario_pago_salarios_2026.csv
├─ grupos_entidades.csv
├─ xiii_mes_2026.csv
├─ calendario_pago_2026.duckdb
├─ data/                           <- JSON publicado (copia de referencia)
│  ├─ manifest.json
│  ├─ calendario.json
│  ├─ grupos_entidades.json
│  └─ xiii_mes.json
├─ pipeline/                       <- generación y scraping
│  ├─ scraper_mef.py
│  ├─ build_dataset.py             <- source of truth de los datos
│  └─ processed.json
└─ worker/                         <- Cloudflare Worker (el "API")
   ├─ src/index.js                 <- rutas /v1/*, CORS, ETag/304, cron scheduled
   ├─ src/mef.js                   <- detección de semestres del MEF (port del scraper)
   ├─ src/data/*.json              <- datos empacados (los genera build_dataset.py)
   ├─ wrangler.toml                <- config + cron trigger + KV opcional
   ├─ package.json
   └─ .gitignore
```
