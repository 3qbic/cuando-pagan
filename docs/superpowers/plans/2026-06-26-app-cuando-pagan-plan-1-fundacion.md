# App "¿Cuándo Pagan?" — Plan 1: Fundación (scaffold + dominio + datos)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir el núcleo headless de la app — proyecto Flutter multiplataforma, modelos de dominio, lógica pura de fechas (con TDD) y la capa de datos offline-first que consume el Cloudflare Worker existente — dejando todo probado por tests de unidad antes de tocar UI.

**Architecture:** Clean architecture feature-first. `domain` es Dart puro (cero imports de Flutter/red) y contiene entidades + lógica (`hoyPanama`, `proximoPago`, `etiquetaContador`, `detectarModificadas`, búsqueda con siglas, query XIII). `data` implementa repos contra el Worker (`/v1/version`, `/v1/all`, ETag/304), SQLite vía `drift` y una semilla empaquetada. `application` orquesta con Riverpod. La UI llega en el Plan 2.

**Tech Stack:** Flutter (Dart 3), `flutter_riverpod` + `riverpod_annotation`, `drift` + `sqlite3_flutter_libs` + `drift_flutter`, `http`, `shared_preferences`, `timezone`, `intl`. Tests con `flutter_test` + `mocktail`.

**Spec de referencia:** `docs/superpowers/specs/2026-06-26-app-cuando-pagan-design.md` (§B = arquitectura, §0.1 = correcciones vinculantes que **prevalecen** sobre el cuerpo).

## Global Constraints

Requisitos de proyecto (de §0 y §0.1 del spec). **Aplican a TODA tarea**, copiados verbatim:

- **Posicionamiento:** app independiente · no oficial · sin afiliación gubernamental. El MEF solo se cita como "fuente pública". (premisa 1)
- **Regla "oficial" (§0.1-A2):** la palabra *oficial* solo modifica al canal/sitio/publicación del MEF, **nunca** a la app, sus datos o fechas.
- **Plataformas / targets (§0 premisa 2 + decisiones):** Android = primaria (`minSdk 24`, Android 7.0), iOS **16.0**, Web. Sin iOS < 16.
- **Modelo de fecha v1 = "solo fuente pública" (premisa 3):** estados `Publicada`/`Pendiente`/`Modificada`/`Desactualizada`; `Estimada` existe en el enum pero **nunca se emite en v1** (Fase 2).
- **Zona horaria (premisa 7):** todo "hoy"/días restantes usa `America/Panamá` (UTC-5, sin DST) **fijo**, nunca la zona del dispositivo.
- **Fecha verbatim:** `fecha_pago` se usa tal cual viene del Worker; cero corrimiento por fin de semana/feriado en cliente.
- **Parsing forward-compatible (§0.1-B10):** `fromWire` de enums usa `orElse` → default seguro (`publicada`/`exacta`), nunca crashea por un valor nuevo.
- **Siglas/alias (§0.1-B7):** capa curada en el repo, búsqueda normalizada (sin acentos, por sigla y por nombre). Ej.: "MIDES" → "Min. de Desarrollo Social" (GRUPO 3).
- **XIII Mes bajo demanda (§0.1-B8):** dato de `xiii_mes.json` (no hardcodeado); se surface solo al buscarlo; etiqueta "Aproximada".
- **Privacidad (premisa 6 + §0.1-E23):** sin cuentas, sin datos personales, todo local; el cliente no envía headers identificantes (solo `If-None-Match` con el ETag global).
- **Gobernanza de dependencias (§B-7):** PROHIBIDOS `firebase_analytics`, `firebase_crashlytics`, `sentry_flutter`, `amplitude`, `google_mobile_ads`, `appsflyer`, `facebook_*`, y cualquier uso de `AdvertisingIdClient`/`ATTrackingManager`. Un check de CI debe romper el build si aparecen.
- **Principios (§0.1-G):** SOLID (sobre todo DIP: la UI/aplicación dependen de interfaces de dominio, no de `drift`/`http`), DRY con criterio (YAGNI + regla de tres), TDD en la capa de dominio.

**Contrato del Worker (consumido, no se modifica):**
- `GET /v1/version` → `{ data_version:int, fecha_publicacion:str, semestres:[str], total_filas:int }`
- `GET /v1/all` → `{ manifest, calendario:[fila], grupos_entidades:[{grupo,entidad}], xiii_mes:[{anio,semestre,mes,fecha_aprox}] }`, con header `ETag: "v{data_version}"` y `304` ante `If-None-Match` coincidente.
- Fila de `calendario`: `{ anio, semestre, mes, mes_num, categoria, quincena, inicio_registro, cierre_registro, retencion_ach, fecha_pago }` (fechas ISO `YYYY-MM-DD`).

---

## Estructura de archivos (este plan)

```
(raíz nueva del proyecto Flutter; el repo actual queda como pipeline/worker/data)
pubspec.yaml                          # deps + assets (semilla, fuentes)
analysis_options.yaml                 # lints
tool/check_forbidden_deps.dart        # CI: rompe build si hay dep prohibida
assets/seed/all.json                  # snapshot de /v1/all (semilla offline)
assets/data/siglas_entidades.json     # mapa curado sigla→nombre (capa de la app)
lib/
├── core/
│   ├── time/tz.dart                  # init zona America/Panama
│   ├── time/hoy_panama.dart          # hoyPanama() / hoyPanamaIso()
│   ├── text/normalizar.dart          # normaliza (minúsculas, sin acentos) p/ búsqueda
│   └── constants/umbrales.dart       # kUmbralStaleDias, kMargenCoberturaDias, kWorkerBaseUrl
├── domain/
│   ├── entities/categoria.dart       # enum Categoria (wire/display, fromWire orElse)
│   ├── entities/estado_fecha.dart    # enum EstadoFecha + Precision (fromWire orElse)
│   ├── entities/entidad.dart         # Entidad { nombreWire, display, grupo, siglas }
│   ├── entities/entrada_calendario.dart
│   ├── entities/seleccion.dart       # sealed Seleccion (Categoria | Entidad)
│   ├── entities/proximo_pago.dart
│   ├── entities/manifest.dart        # Manifest + Cambio
│   ├── entities/xiii_mes.dart        # XiiiMes
│   ├── entities/prefs_usuario.dart   # PrefsUsuario + TemaModo
│   ├── repositories/calendario_repository.dart   # interfaz
│   ├── repositories/prefs_repository.dart         # interfaz
│   ├── search/buscador_entidades.dart # buscarEntidades(query) con siglas/normalización
│   └── logic/
│       ├── proximo_pago.dart         # calcularProximoPago(...)
│       ├── contador.dart             # etiquetaContador(diasRestantes)
│       └── diff_modificadas.dart     # slotKey() + detectarModificadas()
├── data/
│   ├── remote/dto.dart               # *Dto.fromJson exactos al wire
│   ├── remote/worker_api.dart        # versionCheck() / fetchAll(etag)
│   ├── local/app_database.dart       # drift: tablas + DAO
│   ├── local/prefs_local.dart        # shared_preferences
│   ├── seed/seed_loader.dart         # carga assets/seed/all.json + siglas
│   ├── mappers.dart                  # DTO/row ↔ entidad
│   └── repositories/
│       ├── calendario_repository_impl.dart
│       └── prefs_repository_impl.dart
└── application/
    └── sync_controller.dart          # hidratar→chequear→diff→swap (sin UI)
tests espejan lib/ bajo test/
```

> **Decisión de ubicación:** el proyecto Flutter se crea en la **raíz del repo actual** (que ya contiene `pipeline/`, `worker/`, `data/`). Flutter añade `lib/`, `test/`, `android/`, `ios/`, `web/`, `pubspec.yaml` sin chocar con esas carpetas. Si prefieres un subdirectorio `app/`, ajústalo en la Task 1 (afecta solo rutas, no el diseño).

---

### Task 1: Scaffold del proyecto Flutter + lints + check de dependencias prohibidas

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `tool/check_forbidden_deps.dart`, `lib/core/constants/umbrales.dart`
- Create (por `flutter create`): `android/`, `ios/`, `web/`, `lib/main.dart`
- Test: `test/tool/check_forbidden_deps_test.dart`

**Interfaces:**
- Produces: `kWorkerBaseUrl`, `kUmbralStaleDias`, `kMargenCoberturaDias` (constantes globales).

- [ ] **Step 1: Crear el proyecto Flutter en la raíz**

Run:
```bash
cd /Users/alexisgarcia/proyectos/calendario-pago-pa
flutter create --org app.cuandopagan --project-name cuando_pagan \
  --platforms=android,ios,web --description "App independiente y no oficial para consultar fechas de pago del sector público de Panamá." .
```
Expected: crea `lib/`, `test/`, `android/`, `ios/`, `web/`, `pubspec.yaml`. No toca `pipeline/`, `worker/`, `data/`.

- [ ] **Step 2: Fijar targets de plataforma**

En `android/app/build.gradle` (o `build.gradle.kts`), poner `minSdk = 24`. En `ios/Podfile`, fijar `platform :ios, '16.0'` y en Xcode el deployment target a 16.0 (`ios/Flutter/AppFrameworkInfo.plist` → `MinimumOSVersion` 16.0).

Además, en `android/app/src/main/AndroidManifest.xml` añadir dentro de `<manifest ...>` el namespace `tools` (`xmlns:tools="http://schemas.android.com/tools"`) y remover el Advertising ID (invariante no-tracking, §B-7/§0.1-E23):
```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>
```
Borrar el test de andamiaje que genera `flutter create` (pumpea el contador por defecto y estorbará al cambiar `main.dart` en el Plan 2):
```bash
rm -f test/widget_test.dart
```

- [ ] **Step 3: Declarar dependencias en `pubspec.yaml`**

```yaml
name: cuando_pagan
description: "App independiente y no oficial para consultar fechas de pago del sector público de Panamá."
publish_to: "none"
version: 0.1.0+1
environment:
  sdk: ">=3.4.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  drift: ^2.18.0
  drift_flutter: ^0.2.0
  sqlite3_flutter_libs: ^0.5.24
  path_provider: ^2.1.3
  shared_preferences: ^2.2.3
  http: ^1.2.2
  timezone: ^0.9.4
  intl: ^0.19.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.4
  build_runner: ^2.4.11
  drift_dev: ^2.18.0
  riverpod_generator: ^2.4.0
  flutter_lints: ^4.0.0
flutter:
  uses-material-design: true
  assets:
    - assets/seed/all.json
    - assets/data/siglas_entidades.json
```

Run: `flutter pub get`
Expected: resuelve sin errores.

- [ ] **Step 4: Escribir el test del check de dependencias prohibidas**

Create `test/tool/check_forbidden_deps_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import '../../tool/check_forbidden_deps.dart' as checker;

void main() {
  test('detecta una dependencia prohibida', () {
    final hits = checker.findForbidden('''
dependencies:
  http: ^1.2.2
  firebase_analytics: ^11.0.0
''');
    expect(hits, contains('firebase_analytics'));
  });

  test('pubspec limpio no reporta nada', () {
    final hits = checker.findForbidden('''
dependencies:
  http: ^1.2.2
  drift: ^2.18.0
''');
    expect(hits, isEmpty);
  });
}
```

- [ ] **Step 5: Ejecutar el test (debe fallar)**

Run: `flutter test test/tool/check_forbidden_deps_test.dart`
Expected: FAIL — `check_forbidden_deps.dart` no existe / `findForbidden` no definido.

- [ ] **Step 6: Implementar el checker**

Create `tool/check_forbidden_deps.dart`:
```dart
import 'dart:io';

const forbidden = <String>[
  'firebase_analytics', 'firebase_crashlytics', 'sentry_flutter',
  'amplitude', 'google_mobile_ads', 'appsflyer', 'facebook_',
];

List<String> findForbidden(String pubspec) {
  final hits = <String>[];
  for (final name in forbidden) {
    final re = RegExp('^\\s*$name', multiLine: true);
    if (re.hasMatch(pubspec)) hits.add(name);
  }
  return hits;
}

void main() {
  final hits = findForbidden(File('pubspec.yaml').readAsStringSync());
  if (hits.isNotEmpty) {
    stderr.writeln('Dependencias prohibidas (gobernanza no-tracking): $hits');
    exit(1);
  }
  stdout.writeln('OK: sin dependencias prohibidas.');
}
```

- [ ] **Step 7: Crear constantes globales**

Create `lib/core/constants/umbrales.dart`:
```dart
/// Base del Cloudflare Worker existente. Reemplazar por la URL real tras `wrangler deploy`.
const String kWorkerBaseUrl = 'https://calendario-pago-pa.example.workers.dev';

/// Días sin fecha futura ni publicación nueva tras los cuales el dato se considera desactualizado.
const int kUmbralStaleDias = 195;

/// Margen tras la última fecha cubierta del dataset para marcar desactualizado.
const int kMargenCoberturaDias = 14;
```

- [ ] **Step 8: Ejecutar tests y verificar que pasan**

Run: `flutter test test/tool/check_forbidden_deps_test.dart && dart run tool/check_forbidden_deps.dart`
Expected: tests PASS; el checker imprime `OK: sin dependencias prohibidas.`

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml analysis_options.yaml tool/ lib/core/constants/ test/tool/ android/ ios/ web/ lib/main.dart .gitignore
git commit -m "feat(scaffold): proyecto Flutter multiplataforma + check de deps prohibidas"
```

---

### Task 2: Zona horaria de Panamá y `hoyPanama()`

**Files:**
- Create: `lib/core/time/tz.dart`, `lib/core/time/hoy_panama.dart`
- Test: `test/core/time/hoy_panama_test.dart`

**Interfaces:**
- Produces:
  - `void initZonaPanama()` — inicializa la base de datos de zonas y fija `America/Panama`.
  - `DateTime hoyPanama({DateTime? ahora})` — medianoche de hoy en hora de Panamá (UTC-5), como `DateTime` en UTC para comparación estable. `ahora` inyectable para tests.
  - `String hoyPanamaIso({DateTime? ahora})` — `YYYY-MM-DD` de hoy en Panamá.

- [ ] **Step 1: Escribir el test**

Create `test/core/time/hoy_panama_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/core/time/hoy_panama.dart';

void main() {
  setUpAll(initZonaPanama);

  test('a las 23:30 UTC del 26-jun el día en Panamá (UTC-5) sigue siendo 26-jun', () {
    final ahora = DateTime.utc(2026, 6, 26, 23, 30); // 18:30 en Panamá
    expect(hoyPanamaIso(ahora: ahora), '2026-06-26');
  });

  test('a las 04:30 UTC del 27-jun en Panamá aún es 26-jun (23:30 del 26)', () {
    final ahora = DateTime.utc(2026, 6, 27, 4, 30); // 23:30 del 26 en Panamá
    expect(hoyPanamaIso(ahora: ahora), '2026-06-26');
  });

  test('a las 05:30 UTC del 27-jun en Panamá ya es 27-jun (00:30)', () {
    final ahora = DateTime.utc(2026, 6, 27, 5, 30); // 00:30 del 27 en Panamá
    expect(hoyPanamaIso(ahora: ahora), '2026-06-27');
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/core/time/hoy_panama_test.dart`
Expected: FAIL — `tz.dart`/`hoy_panama.dart` no existen.

- [ ] **Step 3: Implementar tz + hoyPanama**

Create `lib/core/time/tz.dart`:
```dart
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Inicializa la base de zonas. Llamar una vez en bootstrap y en setUpAll de tests.
void initZonaPanama() {
  tzdata.initializeTimeZones();
}

/// Ubicación fija: Panamá (UTC-5, sin horario de verano).
tz.Location get panama => tz.getLocation('America/Panama');
```

Create `lib/core/time/hoy_panama.dart`:
```dart
import 'package:timezone/timezone.dart' as tz;
import 'tz.dart';

/// Medianoche de "hoy" en hora de Panamá, normalizada a UTC para comparar fechas.
DateTime hoyPanama({DateTime? ahora}) {
  final base = ahora ?? DateTime.now().toUtc();
  final enPanama = tz.TZDateTime.from(base, panama);
  return DateTime.utc(enPanama.year, enPanama.month, enPanama.day);
}

/// "YYYY-MM-DD" de hoy en Panamá.
String hoyPanamaIso({DateTime? ahora}) {
  final h = hoyPanama(ahora: ahora);
  final mm = h.month.toString().padLeft(2, '0');
  final dd = h.day.toString().padLeft(2, '0');
  return '${h.year}-$mm-$dd';
}
```

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

Run: `flutter test test/core/time/hoy_panama_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/time/ test/core/time/
git commit -m "feat(time): zona America/Panama fija + hoyPanama() con tests de borde de medianoche"
```

---

### Task 3: Enums de dominio (`Categoria`, `EstadoFecha`, `Precision`) con parsing tolerante

**Files:**
- Create: `lib/domain/entities/categoria.dart`, `lib/domain/entities/estado_fecha.dart`
- Test: `test/domain/entities/enums_test.dart`

**Interfaces:**
- Produces:
  - `enum Categoria` con `String wire`, `String display`, `static Categoria fromWire(String)` (default `grupo3` + nunca lanza... ver nota), helper `Categoria? fromWireOrNull(String)`.
  - `enum EstadoFecha { publicada, modificada, pendiente, desactualizada, estimada }` con `static EstadoFecha fromWire(String, {EstadoFecha fallback})`.
  - `enum Precision { exacta, aproximada }` con `static Precision fromWire(String, {Precision fallback})`.

- [ ] **Step 1: Escribir el test**

Create `test/domain/entities/enums_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';

void main() {
  group('Categoria', () {
    test('mapea wire conocido a display normalizado', () {
      expect(Categoria.fromWire('GRUPO 3'), Categoria.grupo3);
      expect(Categoria.grupo3.display, 'Grupo 3');
      expect(Categoria.fromWire('GASTOS DE REPRESENTACION').display,
          'Gastos de representación');
    });
    test('wire desconocido NO crashea: devuelve null en OrNull', () {
      expect(Categoria.fromWireOrNull('GRUPO 9'), isNull);
    });
  });

  group('EstadoFecha', () {
    test('wire desconocido cae al fallback seguro (publicada)', () {
      expect(EstadoFecha.fromWire('inventado'), EstadoFecha.publicada);
      expect(EstadoFecha.fromWire('modificada'), EstadoFecha.modificada);
    });
  });

  group('Precision', () {
    test('default exacta; reconoce aproximada', () {
      expect(Precision.fromWire('cualquiera'), Precision.exacta);
      expect(Precision.fromWire('aproximada'), Precision.aproximada);
    });
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/domain/entities/enums_test.dart`
Expected: FAIL — archivos no existen.

- [ ] **Step 3: Implementar los enums**

Create `lib/domain/entities/categoria.dart`:
```dart
/// Las 5 categorías del dataset. `wire` = string EXACTO del Worker (MAYÚSCULAS).
enum Categoria {
  jubilados('JUBILADOS', 'Jubilados'),
  gastosRepresentacion('GASTOS DE REPRESENTACION', 'Gastos de representación'),
  grupo1('GRUPO 1', 'Grupo 1'),
  grupo2('GRUPO 2', 'Grupo 2'),
  grupo3('GRUPO 3', 'Grupo 3');

  const Categoria(this.wire, this.display);
  final String wire;
  final String display;

  static Categoria? fromWireOrNull(String s) {
    for (final c in Categoria.values) {
      if (c.wire == s) return c;
    }
    return null;
  }

  /// Tolerante: nunca crashea. Si el wire es desconocido, cae a [fallback].
  static Categoria fromWire(String s, {Categoria fallback = Categoria.grupo3}) =>
      fromWireOrNull(s) ?? fallback;
}
```

Create `lib/domain/entities/estado_fecha.dart`:
```dart
/// Estados de una fecha. `estimada` existe pero NUNCA se emite en v1 (Fase 2).
enum EstadoFecha {
  publicada, modificada, pendiente, desactualizada, estimada;

  static EstadoFecha fromWire(String s, {EstadoFecha fallback = EstadoFecha.publicada}) {
    for (final e in EstadoFecha.values) {
      if (e.name == s.toLowerCase()) return e;
    }
    return fallback;
  }
}

/// Atributo ortogonal al estado. El XIII Mes es 'aproximada'.
enum Precision {
  exacta, aproximada;

  static Precision fromWire(String s, {Precision fallback = Precision.exacta}) {
    for (final p in Precision.values) {
      if (p.name == s.toLowerCase()) return p;
    }
    return fallback;
  }
}
```

> Nota: `fromWire` es **estático dentro del enum** (enhanced enum), igual que `Categoria.fromWire`. Así el test del Step 1 (`EstadoFecha.fromWire(...)`, `Precision.fromWire(...)`) compila sin cambios, y los call sites de Task 9/10 usan `EstadoFecha.fromWire(...)` / `Precision.fromWire(...)`.

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

Run: `flutter test test/domain/entities/enums_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/categoria.dart lib/domain/entities/estado_fecha.dart test/domain/entities/enums_test.dart
git commit -m "feat(domain): enums Categoria/EstadoFecha/Precision con parsing tolerante (no crash)"
```

---

### Task 4: Entidades de datos (`Entidad`, `EntradaCalendario`, `Seleccion`, `Manifest`, `XiiiMes`, `ProximoPago`, `PrefsUsuario`)

**Files:**
- Create: `lib/domain/entities/entidad.dart`, `entrada_calendario.dart`, `seleccion.dart`, `manifest.dart`, `xiii_mes.dart`, `proximo_pago.dart`, `prefs_usuario.dart`
- Test: `test/domain/entities/entrada_calendario_test.dart`

**Interfaces:**
- Produces (firmas que Tasks 5–11 consumen):
  - `class Entidad { String nombreWire; String display; Categoria grupo; List<String> siglas; }`
  - `class EntradaCalendario { int anio, semestre, mesNum, quincena; String mes, inicioRegistro, cierreRegistro, retencionAch, fechaPago; EstadoFecha estado; Precision precision; DateTime get fechaPagoDate; String get slotKey; }`
  - `sealed class Seleccion { Categoria get categoria; String get etiqueta; }` con `SeleccionCategoria(Categoria)` y `SeleccionEntidad(Entidad)`; serialización `String toToken()` / `static Seleccion? fromToken(String, List<Entidad>)`.
  - `class Manifest { int dataVersion; String fechaPublicacion; List<String> semestres; String fuente; int totalFilas; Map<String,int> conteo; List<Cambio>? cambios; }` + `class Cambio { String clave, fechaAnterior, fechaNueva; int desdeVersion; }`
  - `class XiiiMes { int anio, semestre; String mes; String fechaAprox; }`
  - `class ProximoPago { EntradaCalendario? entrada; EstadoFecha estado; int diasRestantes; Seleccion seleccion; String fechaPublicacion; int dataVersion; String fuenteUrl; String? fechaAnterior; Precision precision; bool get hayFecha; }`
  - `class PrefsUsuario { String? seleccionFavorita; bool recordatoriosActivos; int diasAnticipacion; int horaRecordatorioMin; bool ocultarNombreInstitucion; TemaModo temaModo; bool onboardingVisto; bool disclaimerAck; int ultimaDataVersion; String? ultimoChequeoIso; }` + `enum TemaModo { sistema, claro, oscuro }`

- [ ] **Step 1: Escribir el test (slotKey + fechaPagoDate + token de Seleccion)**

Create `test/domain/entities/entrada_calendario_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/entities/entidad.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';

EntradaCalendario _fila() => const EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7,
      categoria: Categoria.grupo3, quincena: 1,
      inicioRegistro: '2026-06-24', cierreRegistro: '2026-07-08',
      retencionAch: '2026-07-15', fechaPago: '2026-07-23');

void main() {
  test('slotKey es estable y único por anio/sem/mes/categoria/quincena', () {
    expect(_fila().slotKey, '2026-S2|7|GRUPO 3|1');
  });

  test('fechaPagoDate parsea ISO a UTC medianoche', () {
    expect(_fila().fechaPagoDate, DateTime.utc(2026, 7, 23));
  });

  test('Seleccion roundtrip por token', () {
    final ent = Entidad(
        nombreWire: 'Min. de Desarrollo Social',
        display: 'Ministerio de Desarrollo Social',
        grupo: Categoria.grupo3, siglas: const ['MIDES']);
    final sel = SeleccionEntidad(ent);
    final token = sel.toToken();
    final back = Seleccion.fromToken(token, [ent]);
    expect(back, isA<SeleccionEntidad>());
    expect(back!.categoria, Categoria.grupo3);
    expect(Seleccion.fromToken('cat:GRUPO 1', const []), isA<SeleccionCategoria>());
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/domain/entities/entrada_calendario_test.dart`
Expected: FAIL — entidades no existen.

- [ ] **Step 3: Implementar las entidades**

Create `lib/domain/entities/entidad.dart`:
```dart
import 'categoria.dart';

class Entidad {
  final String nombreWire; // crudo del dataset, ej. "Min. de Desarrollo Social"
  final String display;    // tildes/expandido para UI, ej. "Ministerio de Desarrollo Social"
  final Categoria grupo;   // join: calendario.categoria == grupos_entidades.grupo
  final List<String> siglas; // capa de la app, ej. ["MIDES"]
  const Entidad({
    required this.nombreWire, required this.display,
    required this.grupo, this.siglas = const [],
  });
}
```

Create `lib/domain/entities/entrada_calendario.dart`:
```dart
import 'categoria.dart';
import 'estado_fecha.dart';

class EntradaCalendario {
  final int anio;
  final int semestre;
  final String mes;       // "ENERO" (wire)
  final int mesNum;
  final Categoria categoria;
  final int quincena;     // 1 | 2
  final String inicioRegistro;
  final String cierreRegistro;
  final String retencionAch;
  final String fechaPago; // ISO 'YYYY-MM-DD' — DATO PRIMARIO
  final EstadoFecha estado;
  final Precision precision;

  const EntradaCalendario({
    required this.anio, required this.semestre, required this.mes,
    required this.mesNum, required this.categoria, required this.quincena,
    required this.inicioRegistro, required this.cierreRegistro,
    required this.retencionAch, required this.fechaPago,
    this.estado = EstadoFecha.publicada, this.precision = Precision.exacta,
  });

  DateTime get fechaPagoDate => DateTime.parse('${fechaPago}T00:00:00Z');
  String get slotKey => '$anio-S$semestre|$mesNum|${categoria.wire}|$quincena';
}
```

Create `lib/domain/entities/seleccion.dart`:
```dart
import 'categoria.dart';
import 'entidad.dart';

/// "Mi institución": una Categoría directa o una Entidad (que resuelve a su grupo).
sealed class Seleccion {
  Categoria get categoria;
  String get etiqueta;
  String toToken();

  /// "cat:GRUPO 3" | "ent:Min. de Desarrollo Social"
  static Seleccion? fromToken(String token, List<Entidad> entidades) {
    if (token.startsWith('cat:')) {
      final c = Categoria.fromWireOrNull(token.substring(4));
      return c == null ? null : SeleccionCategoria(c);
    }
    if (token.startsWith('ent:')) {
      final nombre = token.substring(4);
      for (final e in entidades) {
        if (e.nombreWire == nombre) return SeleccionEntidad(e);
      }
    }
    return null;
  }
}

class SeleccionCategoria extends Seleccion {
  final Categoria cat;
  SeleccionCategoria(this.cat);
  @override
  Categoria get categoria => cat;
  @override
  String get etiqueta => cat.display;
  @override
  String toToken() => 'cat:${cat.wire}';
}

class SeleccionEntidad extends Seleccion {
  final Entidad entidad;
  SeleccionEntidad(this.entidad);
  @override
  Categoria get categoria => entidad.grupo;
  @override
  String get etiqueta => entidad.display;
  @override
  String toToken() => 'ent:${entidad.nombreWire}';
}
```

Create `lib/domain/entities/manifest.dart`:
```dart
class Manifest {
  final int dataVersion;
  final String fechaPublicacion;
  final List<String> semestres;
  final String fuente;
  final int totalFilas;
  final Map<String, int> conteo;
  final List<Cambio>? cambios;
  const Manifest({
    required this.dataVersion, required this.fechaPublicacion,
    required this.semestres, required this.fuente, required this.totalFilas,
    required this.conteo, this.cambios,
  });
}

class Cambio {
  final String clave; // slotKey
  final String fechaAnterior;
  final String fechaNueva;
  final int desdeVersion;
  const Cambio({
    required this.clave, required this.fechaAnterior,
    required this.fechaNueva, required this.desdeVersion,
  });
}
```

Create `lib/domain/entities/xiii_mes.dart`:
```dart
class XiiiMes {
  final int anio;
  final int semestre;
  final String mes;        // "FEBRERO"
  final String fechaAprox; // ISO 'YYYY-MM-DD'
  const XiiiMes({
    required this.anio, required this.semestre,
    required this.mes, required this.fechaAprox,
  });
  DateTime get fechaDate => DateTime.parse('${fechaAprox}T00:00:00Z');
}
```

Create `lib/domain/entities/proximo_pago.dart`:
```dart
import 'entrada_calendario.dart';
import 'estado_fecha.dart';
import 'seleccion.dart';

class ProximoPago {
  final EntradaCalendario? entrada; // null si no hay fecha futura cargada
  final EstadoFecha estado;
  final int diasRestantes;          // inclusivo: 0 => "Te pagan hoy"
  final Seleccion seleccion;
  final String fechaPublicacion;
  final int dataVersion;
  final String fuenteUrl;
  final String? fechaAnterior;      // si estado == modificada
  final Precision precision;

  bool get hayFecha => entrada != null;

  const ProximoPago({
    required this.entrada, required this.estado, required this.diasRestantes,
    required this.seleccion, required this.fechaPublicacion,
    required this.dataVersion, required this.fuenteUrl,
    this.fechaAnterior, this.precision = Precision.exacta,
  });
}
```

Create `lib/domain/entities/prefs_usuario.dart`:
```dart
enum TemaModo { sistema, claro, oscuro }

class PrefsUsuario {
  final String? seleccionFavorita; // token "cat:.." | "ent:.." | null
  final bool recordatoriosActivos;
  final int diasAnticipacion;
  final int horaRecordatorioMin;
  final bool ocultarNombreInstitucion;
  final TemaModo temaModo;
  final bool onboardingVisto;
  final bool disclaimerAck;
  final int ultimaDataVersion;
  final String? ultimoChequeoIso;

  const PrefsUsuario({
    this.seleccionFavorita, this.recordatoriosActivos = false,
    this.diasAnticipacion = 1, this.horaRecordatorioMin = 480,
    this.ocultarNombreInstitucion = false, this.temaModo = TemaModo.sistema,
    this.onboardingVisto = false, this.disclaimerAck = false,
    this.ultimaDataVersion = 0, this.ultimoChequeoIso,
  });

  PrefsUsuario copyWith({
    String? seleccionFavorita, bool? recordatoriosActivos, int? diasAnticipacion,
    int? horaRecordatorioMin, bool? ocultarNombreInstitucion, TemaModo? temaModo,
    bool? onboardingVisto, bool? disclaimerAck, int? ultimaDataVersion,
    String? ultimoChequeoIso,
  }) => PrefsUsuario(
        seleccionFavorita: seleccionFavorita ?? this.seleccionFavorita,
        recordatoriosActivos: recordatoriosActivos ?? this.recordatoriosActivos,
        diasAnticipacion: diasAnticipacion ?? this.diasAnticipacion,
        horaRecordatorioMin: horaRecordatorioMin ?? this.horaRecordatorioMin,
        ocultarNombreInstitucion: ocultarNombreInstitucion ?? this.ocultarNombreInstitucion,
        temaModo: temaModo ?? this.temaModo,
        onboardingVisto: onboardingVisto ?? this.onboardingVisto,
        disclaimerAck: disclaimerAck ?? this.disclaimerAck,
        ultimaDataVersion: ultimaDataVersion ?? this.ultimaDataVersion,
        ultimoChequeoIso: ultimoChequeoIso ?? this.ultimoChequeoIso,
      );
}
```

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

Run: `flutter test test/domain/entities/entrada_calendario_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/entities/ test/domain/entities/entrada_calendario_test.dart
git commit -m "feat(domain): entidades de datos (Entidad, EntradaCalendario, Seleccion, Manifest, XiiiMes, ProximoPago, PrefsUsuario)"
```

---

### Task 5: Normalización de texto + búsqueda de entidades por sigla/nombre (§0.1-B7)

**Files:**
- Create: `lib/core/text/normalizar.dart`, `lib/domain/search/buscador_entidades.dart`, `assets/data/siglas_entidades.json`
- Test: `test/domain/search/buscador_entidades_test.dart`

**Interfaces:**
- Produces:
  - `String normalizar(String)` — minúsculas + sin acentos + trim, para comparación.
  - `List<Entidad> buscarEntidades(String query, List<Entidad> universo)` — filtra por sigla o nombre normalizado; query vacía → universo ordenado por display.

- [ ] **Step 1: Escribir el test**

Create `test/domain/search/buscador_entidades_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entidad.dart';
import 'package:cuando_pagan/domain/search/buscador_entidades.dart';
import 'package:cuando_pagan/core/text/normalizar.dart';

final universo = [
  Entidad(nombreWire: 'Min. de Desarrollo Social', display: 'Ministerio de Desarrollo Social', grupo: Categoria.grupo3, siglas: const ['MIDES']),
  Entidad(nombreWire: 'Min. de Educacion', display: 'Ministerio de Educación', grupo: Categoria.grupo1, siglas: const ['MEDUCA']),
  Entidad(nombreWire: 'Organo Judicial', display: 'Órgano Judicial', grupo: Categoria.grupo3, siglas: const ['OJ']),
];

void main() {
  test('normalizar quita acentos y baja a minúsculas', () {
    expect(normalizar('Educación'), 'educacion');
  });

  test('busca por sigla exacta (MIDES)', () {
    final r = buscarEntidades('MIDES', universo);
    expect(r.single.nombreWire, 'Min. de Desarrollo Social');
    expect(r.single.grupo, Categoria.grupo3);
  });

  test('busca por nombre sin acentos (educacion → MEDUCA)', () {
    final r = buscarEntidades('educacion', universo);
    expect(r.single.siglas, contains('MEDUCA'));
  });

  test('query vacía devuelve todo ordenado por display', () {
    final r = buscarEntidades('', universo);
    expect(r.map((e) => e.display).toList(),
        ['Ministerio de Desarrollo Social', 'Ministerio de Educación', 'Órgano Judicial']);
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/domain/search/buscador_entidades_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar normalización + búsqueda**

Create `lib/core/text/normalizar.dart`:
```dart
/// Normaliza para comparación: minúsculas, sin diacríticos, sin espacios extremos.
String normalizar(String s) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const sin = 'aaaaaeeeeiiiiooooouuuun';
  var r = s.toLowerCase().trim();
  final b = StringBuffer();
  for (final ch in r.split('')) {
    final i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString();
}
```

Create `lib/domain/search/buscador_entidades.dart`:
```dart
import '../entities/entidad.dart';
import '../../core/text/normalizar.dart';

List<Entidad> buscarEntidades(String query, List<Entidad> universo) {
  final q = normalizar(query);
  final ordenado = [...universo]..sort((a, b) => a.display.compareTo(b.display));
  if (q.isEmpty) return ordenado;
  return ordenado.where((e) {
    final porSigla = e.siglas.any((s) => normalizar(s).contains(q));
    final porNombre =
        normalizar(e.display).contains(q) || normalizar(e.nombreWire).contains(q);
    return porSigla || porNombre;
  }).toList();
}
```

- [ ] **Step 4: Crear el mapa curado de siglas (asset)**

Create `assets/data/siglas_entidades.json` (mapa nombreWire → siglas; **capa de la app**, auditable):
```json
{
  "Min. de Desarrollo Social": ["MIDES"],
  "Min. de Educacion": ["MEDUCA"],
  "Min. de Salud": ["MINSA"],
  "Min. de Obras Publicas": ["MOP"],
  "Min. de Economia y Finanzas": ["MEF"],
  "Min. de Gobierno": ["MINGOB"],
  "Min. de Comercio e Industrias": ["MICI"],
  "Min. de Relaciones Exteriores": ["MIRE"],
  "Min. de Desarrollo Agropecuario": ["MIDA"],
  "Min. de Seguridad Publica": ["MINSEG"],
  "Min. de Ambiente": ["MiAMBIENTE"],
  "Min. de Trabajo y Desarrollo Laboral": ["MITRADEL"],
  "Min. de Vivienda": ["MIVIOT"],
  "Min. de la Mujer": ["MINMUJER"],
  "Min. de Cultura": ["MiCULTURA"],
  "Min. de la Presidencia": ["MPRE"],
  "Organo Judicial": ["OJ"],
  "Contraloria General": ["CGR"],
  "Asamblea Nacional": ["AN"],
  "Tribunal Electoral": ["TE"]
}
```

> Cobertura: cubre las entidades con sigla de uso común. Las que no tengan sigla quedan con `siglas: []` y se buscan solo por nombre. Ampliar este mapa es seguro (no toca el dato de fecha). El `display` con tildes (§0.1-B9) se deriva en el mapper de Task 9; aquí solo van las siglas.

- [ ] **Step 5: Ejecutar tests y verificar que pasan**

Run: `flutter test test/domain/search/buscador_entidades_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/core/text/ lib/domain/search/ assets/data/siglas_entidades.json test/domain/search/
git commit -m "feat(search): búsqueda de entidades por sigla/nombre normalizado + mapa curado de siglas"
```

---

### Task 6: Lógica núcleo `calcularProximoPago()` + estados derivados (§A-4, §B-5)

**Files:**
- Create: `lib/domain/logic/proximo_pago.dart`
- Test: `test/domain/logic/proximo_pago_test.dart`

**Interfaces:**
- Consumes: `EntradaCalendario`, `Seleccion`, `Manifest`, `EstadoFecha`, `hoyPanama`, `kUmbralStaleDias`, `kMargenCoberturaDias`.
- Produces:
  - `ProximoPago calcularProximoPago({ required List<EntradaCalendario> entradasDeCategoria, required Seleccion seleccion, required Manifest manifest, required int remoteDataVersion, DateTime? ahora, })` — elige la 1.ª `fecha_pago >= hoy(Panamá)`; deriva estado (`pendiente`/`desactualizada`) si no hay; `diasRestantes` inclusivo.

- [ ] **Step 1: Escribir el test**

Create `test/domain/logic/proximo_pago_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';
import 'package:cuando_pagan/domain/entities/manifest.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';
import 'package:cuando_pagan/domain/logic/proximo_pago.dart';

EntradaCalendario fila(String fechaPago, {int q = 1}) => EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7,
      categoria: Categoria.grupo3, quincena: q,
      inicioRegistro: '', cierreRegistro: '', retencionAch: '',
      fechaPago: fechaPago);

final manifest = const Manifest(
    dataVersion: 1, fechaPublicacion: '2026-06-26',
    semestres: ['2026-S1', '2026-S2'], fuente: 'https://mef',
    totalFilas: 120, conteo: {});

final sel = SeleccionCategoria(Categoria.grupo3);

void main() {
  setUpAll(initZonaPanama);
  final ahora = DateTime.utc(2026, 7, 1, 17, 0); // 12:00 Panamá, 1-jul

  test('elige la primera fecha >= hoy y cuenta días inclusivo', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-23'), fila('2026-07-23'), fila('2026-07-29', q: 2)],
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.entrada!.fechaPago, '2026-07-23');
    expect(pp.estado, EstadoFecha.publicada);
    expect(pp.diasRestantes, 22); // 23-jul menos 1-jul
  });

  test('fecha de hoy => diasRestantes 0 (inclusivo)', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-07-01')],
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.diasRestantes, 0);
    expect(pp.hayFecha, isTrue);
  });

  test('sin fecha futura y misma versión => Pendiente', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-23')],
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.hayFecha, isFalse);
    expect(pp.estado, EstadoFecha.pendiente);
  });

  test('sin fecha futura pero hay versión remota mayor => Desactualizada', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-23')],
      seleccion: sel, manifest: manifest, remoteDataVersion: 2, ahora: ahora);
    expect(pp.estado, EstadoFecha.desactualizada);
  });

  test('última fecha cubierta > 14 días atrás (misma versión) => Desactualizada', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-10')], // 21 días antes del 1-jul
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.estado, EstadoFecha.desactualizada);
  });

  test('borde: última fecha exactamente 14 días atrás => Pendiente (no desactualizada)', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-17')], // 14 días antes del 1-jul, no > 14
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.estado, EstadoFecha.pendiente);
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/domain/logic/proximo_pago_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar la lógica**

Create `lib/domain/logic/proximo_pago.dart`:
```dart
import '../entities/entrada_calendario.dart';
import '../entities/estado_fecha.dart';
import '../entities/manifest.dart';
import '../entities/proximo_pago.dart';
import '../entities/seleccion.dart';
import '../../core/time/hoy_panama.dart';
import '../../core/constants/umbrales.dart';

ProximoPago calcularProximoPago({
  required List<EntradaCalendario> entradasDeCategoria,
  required Seleccion seleccion,
  required Manifest manifest,
  required int remoteDataVersion,
  DateTime? ahora,
}) {
  final hoy = hoyPanama(ahora: ahora);

  final futuras = entradasDeCategoria
      .where((e) => !e.fechaPagoDate.isBefore(hoy))
      .toList()
    ..sort((a, b) => a.fechaPagoDate.compareTo(b.fechaPagoDate));

  if (futuras.isNotEmpty) {
    final e = futuras.first;
    final dias = e.fechaPagoDate.difference(hoy).inDays;
    return ProximoPago(
      entrada: e, estado: e.estado, diasRestantes: dias, seleccion: seleccion,
      fechaPublicacion: manifest.fechaPublicacion, dataVersion: manifest.dataVersion,
      fuenteUrl: manifest.fuente, precision: e.precision,
    );
  }

  // Sin fecha futura: derivar Pendiente vs Desactualizada.
  final desactualizada = _esDesactualizada(
    entradasDeCategoria, manifest, remoteDataVersion, hoy);
  return ProximoPago(
    entrada: null,
    estado: desactualizada ? EstadoFecha.desactualizada : EstadoFecha.pendiente,
    diasRestantes: -1, seleccion: seleccion,
    fechaPublicacion: manifest.fechaPublicacion, dataVersion: manifest.dataVersion,
    fuenteUrl: manifest.fuente,
  );
}

bool _esDesactualizada(List<EntradaCalendario> todas, Manifest manifest,
    int remoteDataVersion, DateTime hoy) {
  if (remoteDataVersion > manifest.dataVersion) return true; // accionable: Actualizar
  if (todas.isEmpty) return false;
  final ultima = todas
      .map((e) => e.fechaPagoDate)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  if (hoy.difference(ultima).inDays > kMargenCoberturaDias) return true;
  final pub = DateTime.parse('${manifest.fechaPublicacion}T00:00:00Z');
  if (hoy.difference(pub).inDays > kUmbralStaleDias) return true;
  return false;
}
```

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

Run: `flutter test test/domain/logic/proximo_pago_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/domain/logic/proximo_pago.dart test/domain/logic/proximo_pago_test.dart
git commit -m "feat(logic): calcularProximoPago con estados derivados Pendiente/Desactualizada (TDD)"
```

---

### Task 7: `etiquetaContador()` (hoy/mañana/N días) y `detectarModificadas()`

**Files:**
- Create: `lib/domain/logic/contador.dart`, `lib/domain/logic/diff_modificadas.dart`
- Test: `test/domain/logic/contador_test.dart`, `test/domain/logic/diff_modificadas_test.dart`

**Interfaces:**
- Produces:
  - `String etiquetaContador(int diasRestantes)` — `0→"Es hoy"`, `1→"Es mañana"`, `n→"Faltan n días"`, `<0→"Sin fecha próxima"`.
  - `List<Cambio> detectarModificadas({ required List<EntradaCalendario> previas, required List<EntradaCalendario> nuevas, required int desdeVersion })` — compara `fecha_pago` por `slotKey`.

- [ ] **Step 1: Escribir los tests**

Create `test/domain/logic/contador_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/logic/contador.dart';

void main() {
  test('etiquetas de borde', () {
    expect(etiquetaContador(0), 'Es hoy');
    expect(etiquetaContador(1), 'Es mañana');
    expect(etiquetaContador(2), 'Faltan 2 días');
    expect(etiquetaContador(-1), 'Sin fecha próxima');
  });
}
```

Create `test/domain/logic/diff_modificadas_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/logic/diff_modificadas.dart';

EntradaCalendario f(int q, String fecha) => EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7,
      categoria: Categoria.grupo3, quincena: q,
      inicioRegistro: '', cierreRegistro: '', retencionAch: '', fechaPago: fecha);

void main() {
  test('detecta cambio de fecha_pago en el mismo slot', () {
    final cambios = detectarModificadas(
      previas: [f(1, '2026-07-23'), f(2, '2026-07-29')],
      nuevas: [f(1, '2026-07-24'), f(2, '2026-07-29')],
      desdeVersion: 1);
    expect(cambios, hasLength(1));
    expect(cambios.single.clave, '2026-S2|7|GRUPO 3|1');
    expect(cambios.single.fechaAnterior, '2026-07-23');
    expect(cambios.single.fechaNueva, '2026-07-24');
  });

  test('sin cambios => lista vacía', () {
    final cambios = detectarModificadas(
      previas: [f(1, '2026-07-23')], nuevas: [f(1, '2026-07-23')], desdeVersion: 1);
    expect(cambios, isEmpty);
  });
}
```

- [ ] **Step 2: Ejecutar los tests (deben fallar)**

Run: `flutter test test/domain/logic/contador_test.dart test/domain/logic/diff_modificadas_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar**

Create `lib/domain/logic/contador.dart`:
```dart
String etiquetaContador(int diasRestantes) {
  if (diasRestantes < 0) return 'Sin fecha próxima';
  if (diasRestantes == 0) return 'Es hoy';
  if (diasRestantes == 1) return 'Es mañana';
  return 'Faltan $diasRestantes días';
}
```

Create `lib/domain/logic/diff_modificadas.dart`:
```dart
import '../entities/entrada_calendario.dart';
import '../entities/manifest.dart';

List<Cambio> detectarModificadas({
  required List<EntradaCalendario> previas,
  required List<EntradaCalendario> nuevas,
  required int desdeVersion,
}) {
  final mapPrev = {for (final e in previas) e.slotKey: e.fechaPago};
  final cambios = <Cambio>[];
  for (final n in nuevas) {
    final antes = mapPrev[n.slotKey];
    if (antes != null && antes != n.fechaPago) {
      cambios.add(Cambio(
        clave: n.slotKey, fechaAnterior: antes,
        fechaNueva: n.fechaPago, desdeVersion: desdeVersion));
    }
  }
  return cambios;
}
```

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

Run: `flutter test test/domain/logic/contador_test.dart test/domain/logic/diff_modificadas_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/logic/contador.dart lib/domain/logic/diff_modificadas.dart test/domain/logic/contador_test.dart test/domain/logic/diff_modificadas_test.dart
git commit -m "feat(logic): etiquetaContador + detectarModificadas (diff por slotKey) con tests"
```

---

### Task 8: Consulta XIII Mes bajo demanda (§0.1-B8)

**Files:**
- Create: `lib/domain/logic/consulta_xiii.dart`
- Test: `test/domain/logic/consulta_xiii_test.dart`

**Interfaces:**
- Consumes: `XiiiMes`, `normalizar`, `hoyPanama`.
- Produces:
  - `bool consultaEsSobreXiii(String query)` — true si el texto menciona "decimo tercer", "xiii", "13", "decimotercer", "treceavo".
  - `List<XiiiMes> proximasXiii(List<XiiiMes> todas, {DateTime? ahora})` — fechas `>= hoy` ordenadas; si ninguna futura, devuelve todas ordenadas.

- [ ] **Step 1: Escribir el test**

Create `test/domain/logic/consulta_xiii_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/xiii_mes.dart';
import 'package:cuando_pagan/domain/logic/consulta_xiii.dart';

final xiii = const [
  XiiiMes(anio: 2026, semestre: 1, mes: 'FEBRERO', fechaAprox: '2026-02-20'),
  XiiiMes(anio: 2026, semestre: 2, mes: 'AGOSTO', fechaAprox: '2026-08-06'),
  XiiiMes(anio: 2026, semestre: 2, mes: 'DICIEMBRE', fechaAprox: '2026-12-04'),
];

void main() {
  setUpAll(initZonaPanama);

  test('reconoce variantes de la consulta del XIII', () {
    expect(consultaEsSobreXiii('cuando pagan el decimo tercer mes'), isTrue);
    expect(consultaEsSobreXiii('XIII'), isTrue);
    expect(consultaEsSobreXiii('decimotercer'), isTrue);
    expect(consultaEsSobreXiii('grupo 3'), isFalse);
  });

  test('proximasXiii filtra >= hoy', () {
    final ahora = DateTime.utc(2026, 9, 1, 17, 0); // sep => próxima es dic
    final r = proximasXiii(xiii, ahora: ahora);
    expect(r.first.mes, 'DICIEMBRE');
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/domain/logic/consulta_xiii_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar**

Create `lib/domain/logic/consulta_xiii.dart`:
```dart
import '../entities/xiii_mes.dart';
import '../../core/text/normalizar.dart';
import '../../core/time/hoy_panama.dart';

bool consultaEsSobreXiii(String query) {
  final q = normalizar(query);
  const claves = ['decimo tercer', 'decimotercer', 'treceavo', 'xiii', '13'];
  return claves.any(q.contains);
}

List<XiiiMes> proximasXiii(List<XiiiMes> todas, {DateTime? ahora}) {
  final hoy = hoyPanama(ahora: ahora);
  final orden = [...todas]..sort((a, b) => a.fechaDate.compareTo(b.fechaDate));
  final futuras = orden.where((x) => !x.fechaDate.isBefore(hoy)).toList();
  return futuras.isNotEmpty ? futuras : orden;
}
```

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

Run: `flutter test test/domain/logic/consulta_xiii_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/logic/consulta_xiii.dart test/domain/logic/consulta_xiii_test.dart
git commit -m "feat(logic): consulta XIII bajo demanda (detección + próximas fechas aproximadas)"
```

---

### Task 9: DTOs + mappers + `WorkerApi` (ETag/304)

**Files:**
- Create: `lib/data/remote/dto.dart`, `lib/data/mappers.dart`, `lib/data/remote/worker_api.dart`
- Test: `test/data/remote/worker_api_test.dart`

**Interfaces:**
- Consumes: entidades de Tasks 3–4, `kWorkerBaseUrl`, asset de siglas.
- Produces:
  - `class VersionInfo { int dataVersion; String fechaPublicacion; List<String> semestres; int totalFilas; }`
  - `class AllPayload { Manifest manifest; List<EntradaCalendario> calendario; List<Entidad> entidades; List<XiiiMes> xiii; }`
  - `class WorkerApi { WorkerApi(http.Client, {String baseUrl}); Future<VersionInfo> versionCheck(); Future<AllResponse> fetchAll({String? etag}); }`
  - `class AllResponse { bool notModified; String? etag; AllPayload? payload; }`
  - `Map<String,List<String>> cargarSiglas(String jsonStr)` y `List<Entidad> construirEntidades(List rawGrupos, Map<String,List<String>> siglas)` (en mappers).

- [ ] **Step 1: Escribir el test (con cliente http falso)**

Create `test/data/remote/worker_api_test.dart`:
```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cuando_pagan/data/remote/worker_api.dart';

void main() {
  test('versionCheck parsea /v1/version', () async {
    final client = MockClient((req) async {
      expect(req.url.path, '/v1/version');
      return http.Response(jsonEncode({
        'data_version': 3, 'fecha_publicacion': '2026-06-26',
        'semestres': ['2026-S1', '2026-S2'], 'total_filas': 120,
      }), 200);
    });
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final v = await api.versionCheck();
    expect(v.dataVersion, 3);
    expect(v.semestres, contains('2026-S2'));
  });

  test('fetchAll envía If-None-Match y maneja 304', () async {
    final client = MockClient((req) async {
      expect(req.headers['If-None-Match'], '"v3"');
      return http.Response('', 304);
    });
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final r = await api.fetchAll(etag: '"v3"');
    expect(r.notModified, isTrue);
    expect(r.payload, isNull);
  });

  test('fetchAll 200 mapea calendario, grupos y xiii', () async {
    final body = {
      'manifest': {
        'data_version': 3, 'fecha_publicacion': '2026-06-26',
        'semestres': ['2026-S2'], 'fuente': 'https://mef', 'total_filas': 1, 'conteo': {}
      },
      'calendario': [{
        'anio': 2026, 'semestre': 2, 'mes': 'JULIO', 'mes_num': 7,
        'categoria': 'GRUPO 3', 'quincena': 1, 'inicio_registro': '2026-06-24',
        'cierre_registro': '2026-07-08', 'retencion_ach': '2026-07-15',
        'fecha_pago': '2026-07-23'
      }],
      'grupos_entidades': [{'grupo': 'GRUPO 3', 'entidad': 'Min. de Desarrollo Social'}],
      'xiii_mes': [{'anio': 2026, 'semestre': 2, 'mes': 'AGOSTO', 'fecha_aprox': '2026-08-06'}],
    };
    final client = MockClient((req) async =>
        http.Response(jsonEncode(body), 200, headers: {'etag': '"v3"'}));
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final r = await api.fetchAll();
    expect(r.notModified, isFalse);
    expect(r.etag, '"v3"');
    expect(r.payload!.calendario.single.fechaPago, '2026-07-23');
    expect(r.payload!.entidades.single.grupo.wire, 'GRUPO 3');
    expect(r.payload!.entidades.single.display, 'Ministerio de Desarrollo Social'); // B9: "Min."→"Ministerio de"
    expect(r.payload!.xiii.single.mes, 'AGOSTO');
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/data/remote/worker_api_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar DTOs + mappers + WorkerApi**

Create `lib/data/mappers.dart`:
```dart
import '../domain/entities/categoria.dart';
import '../domain/entities/entidad.dart';
import '../domain/entities/entrada_calendario.dart';
import '../domain/entities/estado_fecha.dart';
import '../domain/entities/manifest.dart';
import '../domain/entities/xiii_mes.dart';

EntradaCalendario entradaFromJson(Map<String, dynamic> j) => EntradaCalendario(
      anio: j['anio'] as int, semestre: j['semestre'] as int,
      mes: j['mes'] as String, mesNum: j['mes_num'] as int,
      categoria: Categoria.fromWire(j['categoria'] as String),
      quincena: j['quincena'] as int,
      inicioRegistro: (j['inicio_registro'] ?? '') as String,
      cierreRegistro: (j['cierre_registro'] ?? '') as String,
      retencionAch: (j['retencion_ach'] ?? '') as String,
      fechaPago: j['fecha_pago'] as String,
      estado: EstadoFecha.fromWire((j['estado'] ?? 'publicada') as String),
      precision: Precision.fromWire((j['precision'] ?? 'exacta') as String),
    );

XiiiMes xiiiFromJson(Map<String, dynamic> j) => XiiiMes(
      anio: j['anio'] as int, semestre: j['semestre'] as int,
      mes: j['mes'] as String, fechaAprox: j['fecha_aprox'] as String,
    );

Manifest manifestFromJson(Map<String, dynamic> j) => Manifest(
      dataVersion: j['data_version'] as int,
      fechaPublicacion: j['fecha_publicacion'] as String,
      semestres: (j['semestres'] as List).cast<String>(),
      fuente: (j['fuente'] ?? '') as String,
      totalFilas: (j['total_filas'] ?? 0) as int,
      conteo: ((j['conteo'] ?? {}) as Map).map((k, v) => MapEntry(k as String, v as int)),
    );

/// Mapa nombreWire -> siglas (del asset). DRY: única fuente de siglas.
Map<String, List<String>> cargarSiglas(Map<String, dynamic> j) =>
    j.map((k, v) => MapEntry(k, (v as List).cast<String>()));

/// Aplica tildes/expansión "Min."->"Ministerio de" para el display (§0.1-B9).
String displayEntidad(String nombreWire) {
  var d = nombreWire.replaceFirst(RegExp(r'^Min\.\s*de\s+'), 'Ministerio de ');
  const tildes = {
    'Educacion': 'Educación', 'Economia': 'Economía', 'Obras Publicas': 'Obras Públicas',
    'Organo Judicial': 'Órgano Judicial', 'Contraloria': 'Contraloría',
    'Procuraduria': 'Procuraduría', 'Administracion': 'Administración',
    'Seguridad Publica': 'Seguridad Pública', 'Region': 'Región',
    'Nacion': 'Nación', 'Fiscalia': 'Fiscalía', 'Defensoria': 'Defensoría',
    'Republica': 'República', 'Admon.': 'Administración',
  };
  tildes.forEach((k, v) => d = d.replaceAll(k, v));
  return d;
}

List<Entidad> construirEntidades(List<dynamic> grupos, Map<String, List<String>> siglas) =>
    grupos.map((g) {
      final m = g as Map<String, dynamic>;
      final nombre = m['entidad'] as String;
      return Entidad(
        nombreWire: nombre, display: displayEntidad(nombre),
        grupo: Categoria.fromWire(m['grupo'] as String),
        siglas: siglas[nombre] ?? const [],
      );
    }).toList();
```

Create `lib/data/remote/dto.dart`:
```dart
import '../../domain/entities/entidad.dart';
import '../../domain/entities/entrada_calendario.dart';
import '../../domain/entities/manifest.dart';
import '../../domain/entities/xiii_mes.dart';

class VersionInfo {
  final int dataVersion;
  final String fechaPublicacion;
  final List<String> semestres;
  final int totalFilas;
  const VersionInfo(this.dataVersion, this.fechaPublicacion, this.semestres, this.totalFilas);
}

class AllPayload {
  final Manifest manifest;
  final List<EntradaCalendario> calendario;
  final List<Entidad> entidades;
  final List<XiiiMes> xiii;
  const AllPayload(this.manifest, this.calendario, this.entidades, this.xiii);
}

class AllResponse {
  final bool notModified;
  final String? etag;
  final AllPayload? payload;
  const AllResponse({required this.notModified, this.etag, this.payload});
}
```

Create `lib/data/remote/worker_api.dart`:
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../mappers.dart';
import 'dto.dart';

class WorkerApi {
  WorkerApi(this._client, {required this.baseUrl});
  final http.Client _client;
  final String baseUrl;

  Future<VersionInfo> versionCheck() async {
    final r = await _client.get(Uri.parse('$baseUrl/v1/version'));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return VersionInfo(
      j['data_version'] as int, j['fecha_publicacion'] as String,
      (j['semestres'] as List).cast<String>(), (j['total_filas'] ?? 0) as int);
  }

  Future<AllResponse> fetchAll({String? etag}) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/v1/all'),
      headers: {if (etag != null) 'If-None-Match': etag},
    );
    if (r.statusCode == 304) return const AllResponse(notModified: true);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    const siglas = <String, List<String>>{}; // las siglas reales las inyecta el repo (Task 11)
    final payload = AllPayload(
      manifestFromJson(j['manifest'] as Map<String, dynamic>),
      (j['calendario'] as List).map((e) => entradaFromJson(e as Map<String, dynamic>)).toList(),
      construirEntidades(j['grupos_entidades'] as List, siglas),
      (j['xiii_mes'] as List).map((e) => xiiiFromJson(e as Map<String, dynamic>)).toList(),
    );
    return AllResponse(notModified: false, etag: r.headers['etag'], payload: payload);
  }
}
```

> Nota de integración de siglas: `WorkerApi` no conoce el asset. El mapa de siglas se inyecta desde el repositorio (Task 11), que carga `assets/data/siglas_entidades.json` una vez y lo pasa a `construirEntidades`. Para mantener `fetchAll` puro, **mover** `construirEntidades` fuera de `fetchAll`: que `fetchAll` devuelva los grupos crudos y el repo construya las entidades con las siglas. Ajuste: `AllPayload.entidades` se rellena en el repo, no en la API. En el test, `siglas` es `{}` (válido: las entidades quedan sin sigla pero con grupo/display). Mantener el test como está; en Task 11 se inyectan las siglas reales.

- [ ] **Step 4: Ejecutar tests y verificar que pasan**

Run: `flutter test test/data/remote/worker_api_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/remote/ lib/data/mappers.dart test/data/remote/
git commit -m "feat(data): WorkerApi (version/all, ETag/304) + DTOs + mappers (display con tildes)"
```

---

### Task 10: Base local `drift` + DAO + semilla

**Files:**
- Create: `lib/data/local/app_database.dart`, `lib/data/seed/seed_loader.dart`, `assets/seed/all.json`
- Test: `test/data/local/app_database_test.dart`

**Interfaces:**
- Produces:
  - Tablas drift `Calendario`, `GruposEntidades`, `XiiiMesT`. (La persistencia de `cambios` se difiere al Plan 2/avisos; en Plan 1 los cambios detectados se devuelven **en memoria** vía `SyncResultado`.)
  - `class AppDatabase { ... }` con DAO embebido:
    - `Future<void> reemplazarCalendario(List<EntradaCalendario>)` (swap atómico).
    - `Future<List<EntradaCalendario>> entradasDeCategoria(Categoria)`.
    - `Future<List<EntradaCalendario>> todas()`.
    - `Future<void> guardarGrupos(List<Entidad>)` / `Future<List<Entidad>> entidades()`.
    - `Future<void> guardarXiii(List<XiiiMes>)` / `Future<List<XiiiMes>> xiiiTodas()`.
  - `String semillaJson()` carga `assets/seed/all.json` (en seed_loader, con `rootBundle`).

- [ ] **Step 1: Generar el snapshot semilla**

Run (usa el pipeline/Worker existentes para producir el snapshot real):
```bash
cd /Users/alexisgarcia/proyectos/calendario-pago-pa
python pipeline/build_dataset.py   # regenera data/ y worker/src/data/
# Construir all.json (manifest+calendario+grupos+xiii) para la semilla:
python - <<'PY'
import json, pathlib
d = pathlib.Path('data')
allp = {
  "manifest": json.loads((d/'manifest.json').read_text()),
  "calendario": json.loads((d/'calendario.json').read_text()),
  "grupos_entidades": json.loads((d/'grupos_entidades.json').read_text()),
  "xiii_mes": json.loads((d/'xiii_mes.json').read_text()),
}
out = pathlib.Path('assets/seed'); out.mkdir(parents=True, exist_ok=True)
(out/'all.json').write_text(json.dumps(allp, ensure_ascii=False))
print('semilla escrita:', (out/'all.json').stat().st_size, 'bytes')
PY
```
Expected: `assets/seed/all.json` creado con el dataset 2026.

- [ ] **Step 2: Escribir el test (DB en memoria)**

Create `test/data/local/app_database_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/data/local/app_database.dart';

EntradaCalendario f(Categoria c, String fecha, {int q = 1}) => EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7, categoria: c, quincena: q,
      inicioRegistro: '', cierreRegistro: '', retencionAch: '', fechaPago: fecha);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('reemplazar + consultar por categoría', () async {
    await db.reemplazarCalendario([
      f(Categoria.grupo3, '2026-07-23'), f(Categoria.grupo1, '2026-07-21'),
    ]);
    final g3 = await db.entradasDeCategoria(Categoria.grupo3);
    expect(g3, hasLength(1));
    expect(g3.single.fechaPago, '2026-07-23');
  });

  test('swap atómico reemplaza todo el contenido', () async {
    await db.reemplazarCalendario([f(Categoria.grupo3, '2026-07-23')]);
    await db.reemplazarCalendario([f(Categoria.grupo3, '2026-08-24')]);
    final g3 = await db.entradasDeCategoria(Categoria.grupo3);
    expect(g3.single.fechaPago, '2026-08-24');
  });
}
```

- [ ] **Step 3: Ejecutar el test (debe fallar)**

Run: `flutter test test/data/local/app_database_test.dart`
Expected: FAIL — `app_database.dart` no existe.

- [ ] **Step 4: Implementar el esquema drift + DAO**

Create `lib/data/local/app_database.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../domain/entities/categoria.dart';
import '../../domain/entities/entrada_calendario.dart';
import '../../domain/entities/estado_fecha.dart';
import '../../domain/entities/entidad.dart';
import '../../domain/entities/xiii_mes.dart';

part 'app_database.g.dart';

class Calendario extends Table {
  IntColumn get anio => integer()();
  IntColumn get semestre => integer()();
  TextColumn get mes => text()();
  IntColumn get mesNum => integer()();
  TextColumn get categoria => text()(); // wire
  IntColumn get quincena => integer()();
  TextColumn get inicioRegistro => text()();
  TextColumn get cierreRegistro => text()();
  TextColumn get retencionAch => text()();
  TextColumn get fechaPago => text()();
  TextColumn get estado => text()();
  TextColumn get precision => text()();
}

class GruposEntidades extends Table {
  TextColumn get nombreWire => text()();
  TextColumn get grupo => text()();
}

class XiiiMesT extends Table {
  IntColumn get anio => integer()();
  IntColumn get semestre => integer()();
  TextColumn get mes => text()();
  TextColumn get fechaAprox => text()();
}

@DriftDatabase(tables: [Calendario, GruposEntidades, XiiiMesT])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'cuando_pagan'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<void> reemplazarCalendario(List<EntradaCalendario> filas) async {
    await transaction(() async {
      await delete(calendario).go();
      await batch((b) => b.insertAll(calendario, filas.map(_toRow)));
    });
  }

  CalendarioCompanion _toRow(EntradaCalendario e) => CalendarioCompanion.insert(
        anio: e.anio, semestre: e.semestre, mes: e.mes, mesNum: e.mesNum,
        categoria: e.categoria.wire, quincena: e.quincena,
        inicioRegistro: e.inicioRegistro, cierreRegistro: e.cierreRegistro,
        retencionAch: e.retencionAch, fechaPago: e.fechaPago,
        estado: e.estado.name, precision: e.precision.name,
      );

  EntradaCalendario _fromRow(CalendarioData r) => EntradaCalendario(
        anio: r.anio, semestre: r.semestre, mes: r.mes, mesNum: r.mesNum,
        categoria: Categoria.fromWire(r.categoria), quincena: r.quincena,
        inicioRegistro: r.inicioRegistro, cierreRegistro: r.cierreRegistro,
        retencionAch: r.retencionAch, fechaPago: r.fechaPago,
        estado: EstadoFecha.fromWire(r.estado),
        precision: Precision.fromWire(r.precision),
      );

  Future<List<EntradaCalendario>> entradasDeCategoria(Categoria c) async {
    final q = select(calendario)..where((t) => t.categoria.equals(c.wire));
    return (await q.get()).map(_fromRow).toList();
  }

  Future<List<EntradaCalendario>> todas() async =>
      (await select(calendario).get()).map(_fromRow).toList();

  Future<void> guardarGrupos(List<Entidad> ents) async {
    await transaction(() async {
      await delete(gruposEntidades).go();
      await batch((b) => b.insertAll(gruposEntidades, ents.map((e) =>
          GruposEntidadesCompanion.insert(nombreWire: e.nombreWire, grupo: e.grupo.wire))));
    });
  }

  Future<List<String>> nombresGruposCrudos() async =>
      (await select(gruposEntidades).get()).map((r) => '${r.nombreWire}|${r.grupo}').toList();

  Future<void> guardarXiii(List<XiiiMes> xs) async {
    await transaction(() async {
      await delete(xiiiMesT).go();
      await batch((b) => b.insertAll(xiiiMesT, xs.map((x) =>
          XiiiMesTCompanion.insert(
              anio: x.anio, semestre: x.semestre, mes: x.mes, fechaAprox: x.fechaAprox))));
    });
  }

  Future<List<XiiiMes>> xiiiTodas() async => (await select(xiiiMesT).get())
      .map((r) => XiiiMes(anio: r.anio, semestre: r.semestre, mes: r.mes, fechaAprox: r.fechaAprox))
      .toList();
}
```

Create `lib/data/seed/seed_loader.dart`:
```dart
import 'package:flutter/services.dart' show rootBundle;

class SeedLoader {
  Future<String> allJson() => rootBundle.loadString('assets/seed/all.json');
  Future<String> siglasJson() => rootBundle.loadString('assets/data/siglas_entidades.json');
}
```

- [ ] **Step 5: Generar el código drift**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: genera `lib/data/local/app_database.g.dart`.

- [ ] **Step 6: Ejecutar tests y verificar que pasan**

Run: `flutter test test/data/local/app_database_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/data/local/ lib/data/seed/ assets/seed/all.json
git commit -m "feat(data): base drift (calendario/grupos/xiii) + DAO con swap atómico + semilla offline"
```

---

### Task 11: `CalendarioRepository` impl + interfaces de dominio + `SyncController` (offline-first)

**Files:**
- Create: `lib/domain/repositories/calendario_repository.dart`, `lib/domain/repositories/prefs_repository.dart`, `lib/data/local/prefs_local.dart`, `lib/data/repositories/calendario_repository_impl.dart`, `lib/data/repositories/prefs_repository_impl.dart`, `lib/application/sync_controller.dart`
- Test: `test/data/repositories/calendario_repository_impl_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `WorkerApi`, `SeedLoader`, lógica de Tasks 6–8, `detectarModificadas`.
- Produces:
  - `abstract class CalendarioRepository { Future<void> asegurarHidratado(); Future<SyncResultado> sincronizar(); Future<ProximoPago> proximoPago(Seleccion); Future<List<Entidad>> entidades(); Future<List<XiiiMes>> xiii(); Manifest get manifestActual; }`
  - `class SyncResultado { bool descargo; int dataVersion; List<Cambio> cambios; }`
  - `abstract class PrefsRepository { ... }` (favorito + flags).
  - `class SyncController { Future<SyncResultado> abrir(); }` (orquesta `asegurarHidratado` + `sincronizar`).

- [ ] **Step 1: Escribir el test (repo con API e infra falsas)**

Create `test/data/repositories/calendario_repository_impl_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';
import 'package:cuando_pagan/data/local/app_database.dart';
import 'package:cuando_pagan/data/repositories/calendario_repository_impl.dart';
import '../../helpers/fakes.dart';

void main() {
  setUpAll(initZonaPanama);

  test('hidrata desde semilla y resuelve próximo pago de GRUPO 3', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = CalendarioRepositoryImpl(
      db: db,
      api: FakeWorkerApi.sinCambios(version: 1),
      seed: FakeSeed.dataset2026(),
      ahora: () => DateTime.utc(2026, 7, 1, 17, 0),
    );
    await repo.asegurarHidratado();
    final pp = await repo.proximoPago(SeleccionCategoria(Categoria.grupo3));
    expect(pp.hayFecha, isTrue);
    expect(pp.estado, EstadoFecha.publicada);
    await db.close();
  });

  test('si remote>local descarga y reporta cambios', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = CalendarioRepositoryImpl(
      db: db,
      api: FakeWorkerApi.conActualizacion(local: 1, remote: 2, cambiaFechaG3: true),
      seed: FakeSeed.dataset2026(),
      ahora: () => DateTime.utc(2026, 7, 1, 17, 0),
    );
    await repo.asegurarHidratado();
    final res = await repo.sincronizar();
    expect(res.descargo, isTrue);
    expect(res.dataVersion, 2);
    expect(res.cambios, isNotEmpty);
    await db.close();
  });
}
```

> Este test depende de `test/helpers/fakes.dart` (FakeWorkerApi, FakeSeed). Crear ese helper en el Step 3 junto con las interfaces, porque define el contrato que el repo consume.

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/data/repositories/calendario_repository_impl_test.dart`
Expected: FAIL — repo y helpers no existen.

- [ ] **Step 3: Implementar interfaces, repo, prefs y helper de fakes**

Create `lib/domain/repositories/calendario_repository.dart`:
```dart
import '../entities/entidad.dart';
import '../entities/manifest.dart';
import '../entities/proximo_pago.dart';
import '../entities/seleccion.dart';
import '../entities/xiii_mes.dart';

class SyncResultado {
  final bool descargo;
  final int dataVersion;
  final List<Cambio> cambios;
  const SyncResultado({required this.descargo, required this.dataVersion, required this.cambios});
}

abstract class CalendarioRepository {
  Future<void> asegurarHidratado();
  Future<SyncResultado> sincronizar();
  Future<ProximoPago> proximoPago(Seleccion seleccion);
  Future<List<Entidad>> entidades();
  Future<List<XiiiMes>> xiii();
  Manifest get manifestActual;
}
```

Create `lib/domain/repositories/prefs_repository.dart`:
```dart
import '../entities/prefs_usuario.dart';

abstract class PrefsRepository {
  Future<PrefsUsuario> cargar();
  Future<void> guardar(PrefsUsuario prefs);
}
```

Create `lib/data/local/prefs_local.dart`:
```dart
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/prefs_usuario.dart';
import '../../domain/repositories/prefs_repository.dart';

class PrefsLocal implements PrefsRepository {
  PrefsLocal(this._sp);
  final SharedPreferences _sp;

  @override
  Future<PrefsUsuario> cargar() async => PrefsUsuario(
        seleccionFavorita: _sp.getString('favorita'),
        recordatoriosActivos: _sp.getBool('recordatorios') ?? false,
        diasAnticipacion: _sp.getInt('anticipacion') ?? 1,
        horaRecordatorioMin: _sp.getInt('horaMin') ?? 480,
        ocultarNombreInstitucion: _sp.getBool('ocultarNombre') ?? false,
        temaModo: TemaModo.values[_sp.getInt('tema') ?? 0],
        onboardingVisto: _sp.getBool('onboarding') ?? false,
        disclaimerAck: _sp.getBool('disclaimerAck') ?? false,
        ultimaDataVersion: _sp.getInt('ultimaVersion') ?? 0,
        ultimoChequeoIso: _sp.getString('ultimoChequeo'),
      );

  @override
  Future<void> guardar(PrefsUsuario p) async {
    await _sp.setBool('recordatorios', p.recordatoriosActivos);
    await _sp.setInt('anticipacion', p.diasAnticipacion);
    await _sp.setInt('horaMin', p.horaRecordatorioMin);
    await _sp.setBool('ocultarNombre', p.ocultarNombreInstitucion);
    await _sp.setInt('tema', p.temaModo.index);
    await _sp.setBool('onboarding', p.onboardingVisto);
    await _sp.setBool('disclaimerAck', p.disclaimerAck);
    await _sp.setInt('ultimaVersion', p.ultimaDataVersion);
    if (p.seleccionFavorita != null) await _sp.setString('favorita', p.seleccionFavorita!);
    if (p.ultimoChequeoIso != null) await _sp.setString('ultimoChequeo', p.ultimoChequeoIso!);
  }
}
```

Create `lib/data/repositories/calendario_repository_impl.dart`:
```dart
import '../../domain/entities/entidad.dart';
import '../../domain/entities/manifest.dart';
import '../../domain/entities/proximo_pago.dart';
import '../../domain/entities/seleccion.dart';
import '../../domain/entities/xiii_mes.dart';
import '../../domain/logic/proximo_pago.dart';
import '../../domain/logic/diff_modificadas.dart';
import '../../domain/repositories/calendario_repository.dart';
import '../local/app_database.dart';
import '../mappers.dart';

/// Abstracción mínima de la fuente remota que el repo necesita (DIP, testeable).
abstract class FuenteRemota {
  Future<int> versionRemota();
  /// Devuelve el JSON crudo de /v1/all o null si 304.
  Future<Map<String, dynamic>?> descargarSiCambio(String? etag);
}

/// Abstracción de la semilla + siglas empaquetadas.
abstract class FuenteSemilla {
  Future<Map<String, dynamic>> allJson();
  Future<Map<String, List<String>>> siglas();
}

class CalendarioRepositoryImpl implements CalendarioRepository {
  CalendarioRepositoryImpl({
    required this.db, required this.api, required this.seed,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? () => DateTime.now().toUtc();

  final AppDatabase db;
  final FuenteRemota api;
  final FuenteSemilla seed;
  final DateTime Function() _ahora;

  Manifest? _manifest;
  Map<String, List<String>> _siglas = const {};

  @override
  Manifest get manifestActual => _manifest!;

  @override
  Future<void> asegurarHidratado() async {
    _siglas = await seed.siglas();
    final yaHay = (await db.todas()).isNotEmpty;
    final j = await seed.allJson();
    _manifest = manifestFromJson(j['manifest'] as Map<String, dynamic>);
    if (!yaHay) {
      await _aplicarPayload(j);
    }
  }

  Future<void> _aplicarPayload(Map<String, dynamic> j) async {
    final cal = (j['calendario'] as List)
        .map((e) => entradaFromJson(e as Map<String, dynamic>)).toList();
    final ents = construirEntidades(j['grupos_entidades'] as List, _siglas);
    final xs = (j['xiii_mes'] as List)
        .map((e) => xiiiFromJson(e as Map<String, dynamic>)).toList();
    await db.reemplazarCalendario(cal);
    await db.guardarGrupos(ents);
    await db.guardarXiii(xs);
    _manifest = manifestFromJson(j['manifest'] as Map<String, dynamic>);
  }

  @override
  Future<SyncResultado> sincronizar() async {
    final local = _manifest!.dataVersion;
    final remote = await api.versionRemota();
    if (remote <= local) {
      return SyncResultado(descargo: false, dataVersion: local, cambios: const []);
    }
    final j = await api.descargarSiCambio('"v$local"');
    if (j == null) {
      return SyncResultado(descargo: false, dataVersion: local, cambios: const []);
    }
    final previas = await db.todas();
    final nuevas = (j['calendario'] as List)
        .map((e) => entradaFromJson(e as Map<String, dynamic>)).toList();
    final cambios = detectarModificadas(
        previas: previas, nuevas: nuevas, desdeVersion: local);
    await _aplicarPayload(j);
    return SyncResultado(descargo: true, dataVersion: remote, cambios: cambios);
  }

  @override
  Future<ProximoPago> proximoPago(Seleccion seleccion) async {
    final entradas = await db.entradasDeCategoria(seleccion.categoria);
    final remote = _manifest!.dataVersion; // sin re-consultar red aquí
    return calcularProximoPago(
      entradasDeCategoria: entradas, seleccion: seleccion,
      manifest: _manifest!, remoteDataVersion: remote, ahora: _ahora());
  }

  @override
  Future<List<Entidad>> entidades() async {
    // reconstruye desde la tabla cruda + siglas (DRY: displayEntidad en mappers)
    final crudos = await db.nombresGruposCrudos();
    return crudos.map((s) {
      final p = s.split('|');
      return construirEntidades([
        {'entidad': p[0], 'grupo': p[1]}
      ], _siglas).single;
    }).toList();
  }

  @override
  Future<List<XiiiMes>> xiii() => db.xiiiTodas();
}
```

Create `test/helpers/fakes.dart`:
```dart
import 'dart:convert';
import 'package:cuando_pagan/data/repositories/calendario_repository_impl.dart';

const _semilla2026 = {
  'manifest': {
    'data_version': 1, 'fecha_publicacion': '2026-06-26',
    'semestres': ['2026-S2'], 'fuente': 'https://mef', 'total_filas': 2, 'conteo': {}
  },
  'calendario': [
    {'anio': 2026, 'semestre': 2, 'mes': 'JULIO', 'mes_num': 7, 'categoria': 'GRUPO 3',
     'quincena': 1, 'inicio_registro': '', 'cierre_registro': '', 'retencion_ach': '',
     'fecha_pago': '2026-07-23'},
    {'anio': 2026, 'semestre': 2, 'mes': 'JULIO', 'mes_num': 7, 'categoria': 'GRUPO 1',
     'quincena': 1, 'inicio_registro': '', 'cierre_registro': '', 'retencion_ach': '',
     'fecha_pago': '2026-07-21'},
  ],
  'grupos_entidades': [
    {'grupo': 'GRUPO 3', 'entidad': 'Min. de Desarrollo Social'},
  ],
  'xiii_mes': [
    {'anio': 2026, 'semestre': 2, 'mes': 'AGOSTO', 'fecha_aprox': '2026-08-06'},
  ],
};

class FakeSeed implements FuenteSemilla {
  FakeSeed.dataset2026();
  @override
  Future<Map<String, dynamic>> allJson() async =>
      jsonDecode(jsonEncode(_semilla2026)) as Map<String, dynamic>;
  @override
  Future<Map<String, List<String>>> siglas() async =>
      {'Min. de Desarrollo Social': ['MIDES']};
}

class FakeWorkerApi implements FuenteRemota {
  FakeWorkerApi._(this._remote, this._payload);
  final int _remote;
  final Map<String, dynamic>? _payload;

  factory FakeWorkerApi.sinCambios({required int version}) =>
      FakeWorkerApi._(version, null);

  factory FakeWorkerApi.conActualizacion(
      {required int local, required int remote, bool cambiaFechaG3 = false}) {
    final p = jsonDecode(jsonEncode(_semilla2026)) as Map<String, dynamic>;
    (p['manifest'] as Map)['data_version'] = remote;
    if (cambiaFechaG3) {
      (p['calendario'] as List).first['fecha_pago'] = '2026-07-24';
    }
    return FakeWorkerApi._(remote, p);
  }

  @override
  Future<int> versionRemota() async => _remote;
  @override
  Future<Map<String, dynamic>?> descargarSiCambio(String? etag) async => _payload;
}
```

> El `CalendarioRepositoryImpl` real (en producción) recibe adaptadores que envuelven `WorkerApi` (Task 9) y `SeedLoader` (Task 10) cumpliendo `FuenteRemota`/`FuenteSemilla`. Esos adaptadores triviales se crean en el Plan 2 (cableado con Riverpod en `application/`), porque dependen de `http.Client` y `rootBundle` (entorno Flutter). Aquí la lógica del repo se prueba 100% con fakes (DIP).

- [ ] **Step 4: Implementar `SyncController`**

Create `lib/application/sync_controller.dart`:
```dart
import '../domain/repositories/calendario_repository.dart';

/// Orquesta el arranque: hidrata (semilla/cache) y luego intenta sincronizar.
/// No conoce UI. La reprogramación de notificaciones se enganchará en el Plan 3.
class SyncController {
  SyncController(this._repo);
  final CalendarioRepository _repo;

  Future<SyncResultado> abrir() async {
    await _repo.asegurarHidratado();
    try {
      return await _repo.sincronizar();
    } catch (_) {
      // offline-first: si falla la red, seguimos con lo hidratado.
      return SyncResultado(
          descargo: false, dataVersion: _repo.manifestActual.dataVersion, cambios: const []);
    }
  }
}
```

- [ ] **Step 5: Ejecutar tests y verificar que pasan**

Run: `flutter test test/data/repositories/calendario_repository_impl_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Ejecutar TODA la suite + el check de deps**

Run: `flutter test && dart run tool/check_forbidden_deps.dart`
Expected: todos los tests PASS; checker imprime OK.

- [ ] **Step 7: Commit**

```bash
git add lib/domain/repositories/ lib/data/local/prefs_local.dart lib/data/repositories/ lib/application/ test/helpers/ test/data/repositories/
git commit -m "feat(data): CalendarioRepository offline-first (hidratar/sincronizar/diff) + interfaces + SyncController (TDD con fakes)"
```

---

## Self-Review (cobertura del subsistema "Fundación")

**Cobertura de los Hitos 0–2 del spec:**
- Hito 0 (Andamiaje): Task 1 (scaffold, lints, CI dep-check, targets, AndroidManifest con `AD_ID` removido, borrado del `widget_test.dart` por defecto); `tokens.dart`/`theme.dart` se mueven al Plan 2 (UI) por cohesión — ✅.
- Hito 1 (Dominio + lógica pura): Tasks 2–8 (tz, enums, entidades, búsqueda+siglas, proximoPago, contador, diff, XIII) con TDD — ✅.
- Hito 2 (Datos offline-first): Tasks 9–11 (WorkerApi/ETag-304, drift+DAO+semilla, repo offline-first, SyncController) — ✅.

**Correcciones vinculantes cubiertas aquí:** B7 (siglas, Task 5), B8 (XIII bajo demanda, Task 8), B9 (display con tildes, Task 9 mapper + assert en test), B10 (parsing tolerante, Task 3), E23 **lado cliente** (sin headers identificantes — solo `If-None-Match`, Task 9; el check de CI del **Worker** sin logging de IP se difiere a un plan del Worker), G28-DIP (repo depende de interfaces `FuenteRemota`/`FuenteSemilla`, Task 11), G30 (TDD en dominio). El resto (A-wording, C-a11y, D-tiendas, F-proceso) corresponde a planes de UI/cumplimiento.

**Diferido explícitamente a planes siguientes (no es hueco):** `tokens.dart`/`theme.dart` y todo widget (Plan 2 UI); notificaciones + widget nativo (Plan 3); textos legales/fichas/política + golden tests de DoD (Plan 4). Adaptadores `FuenteRemota`/`FuenteSemilla` reales (envuelven WorkerApi/SeedLoader) se cablean en el Plan 2.

**Riesgos conocidos a validar en ejecución:** versiones exactas de paquetes (`drift_flutter`, `riverpod_generator`) — el subagente debe resolver con `flutter pub get` y ajustar; API de `drift` generada (`CalendarioData`/`CalendarioCompanion`) según codegen; `MockClient` viene de `package:http/testing.dart`.
