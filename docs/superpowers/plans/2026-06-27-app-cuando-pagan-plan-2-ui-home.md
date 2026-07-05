# App "¿Cuándo Pagan?" — Plan 2: Integración + Design System + Home (Próximo pago)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Llevar la app de núcleo headless a **demoable end-to-end**: resolver las 4 costuras de integración que dejó la revisión de Plan 1, construir el design system "editorial / dark-first", cablear Riverpod + `main.dart`, y la pantalla **Home / Próximo pago** con un selector mínimo de institución — el usuario abre la app, elige su institución y ve cuándo le pagan.

**Architecture:** La capa `data` se completa (adaptadores reales `FuenteRemota`/`FuenteSemilla` sobre `WorkerApi`/`SeedLoader`, un decode único de `/v1/all`, persistencia del `Manifest` y de la última versión remota vía una tabla `AppMeta`, y `PrefsRepository` cableado al repo). `lib/design/` define tokens + `ThemeData` sin `ColorScheme.fromSeed`. `lib/application/` expone `HomeController` (Riverpod `AsyncNotifier`). `lib/features/home/` y `lib/design/widgets/` pintan la UI consumiendo SOLO interfaces de dominio y tokens.

**Tech Stack:** Flutter 3 / Dart 3, `flutter_riverpod`, `drift`, `google_fonts` (self-host, runtime fetch OFF), `intl`, `flutter_test`, `mocktail`.

**Specs de referencia:** `docs/superpowers/specs/2026-06-26-app-cuando-pagan-design.md` — §A (producto/diseño, tokens en §A-5, componentes §A-6), §0.1 (correcciones vinculantes). **Lo de §0.1 prevalece sobre el cuerpo.**

**Estado heredado de Plan 1 (en `lib/`):** dominio puro (`Categoria`, `Entidad{nombreWire,display,grupo,siglas}`, `EntradaCalendario{...,slotKey}`, `EstadoFecha{publicada,modificada,pendiente,desactualizada,estimada}`, `Precision`, `Seleccion`(sealed: `SeleccionCategoria`/`SeleccionEntidad`, `toToken`/`fromToken`), `ProximoPago`, `Manifest`/`Cambio`, `XiiiMes`, `PrefsUsuario`/`TemaModo`); lógica (`calcularProximoPago({entradasDeCategoria, seleccion, manifest, remoteDataVersion, ahora})`, `etiquetaContador(int)`, `detectarModificadas`, `buscarEntidades(query, universo)`, `consultaEsSobreXiii`, `proximasXiii`, `hoyPanama`); datos (`AppDatabase` drift con `entradasDeCategoria/todas/guardarGrupos/nombresGruposCrudos/guardarXiii/xiiiTodas/reemplazarCalendario`; `WorkerApi(http.Client,{baseUrl})` con `versionCheck()/fetchAll({etag})`; `SeedLoader.allJson()/siglasJson()`; mappers `entradaFromJson/xiiiFromJson/manifestFromJson/cargarSiglas/construirEntidades/displayEntidad`); `CalendarioRepositoryImpl({db, api:FuenteRemota, seed:FuenteSemilla, ahora})` con `asegurarHidratado/sincronizar/proximoPago/entidades/xiii`; `PrefsLocal implements PrefsRepository`; `SyncController`.

## Global Constraints

Copiadas verbatim de §0 / §0.1 del spec. **Aplican a TODA tarea.**

- **Posicionamiento (premisa 1, §0.1-A):** app independiente · no oficial · no afiliada. MEF solo como "fuente pública". "oficial" solo modifica al canal/sitio/publicación del MEF, **nunca** a la app/sus datos. Disclaimer "no oficial" **omnipresente y en el árbol de Semantics** = Definition of Done en cada pantalla. Sin escudo/bandera/Marca País como identidad. Verbo rector "consultar fechas", nunca "tu pago"/"trámite".
- **Visual (premisa 5, §A-5):** editorial / dark-first / anti-AI-slop. **NO** `ColorScheme.fromSeed`, **NO** morado M3, **NO** colores de bandera. Lima `#C6F647` + near-black `#0B0B0C` + crema `#F7F5F0`; serif **Fraunces** (display) + grotesca **Space Grotesk** (datos/UI, `tabularFigures`). El lima **solo** aparece como fondo-con-tinta o número grande; jamás como texto de párrafo.
- **A11y (§0.1-C):** estados de fecha = **icono(forma) + etiqueta + color** (nunca solo color, WCAG 1.4.1). Contraste texto esencial ≥4.5:1 (los pares declarados ya corrigen light: `state.modified` light `#8A5A00`, "Aproximada" label light `#8A5A00`). Foco **oscuro** garantizado sobre superficies lima (token `#0B0B0C`, ≥3:1 contra la superficie real, no canvas). Touch target ≥48dp. Texto escala a ≥200% (solo `display/hero` se clampa a 1.3×). Ribbon "no oficial" ≥12px, escala con `textScaler`, hit-target 48dp. Reduce-motion respetado.
- **Tiempo/idioma (premisa 7):** `America/Panamá` fijo (UTC-5) para todo "hoy"/contador. Español panameño. Horas 12h `AM/PM`. `fecha_pago` verbatim.
- **Privacidad/gobernanza (premisa 6, §0.1-E, §B-7):** sin cuentas/datos personales, todo local. Cliente sin headers identificantes (solo `If-None-Match`). PROHIBIDOS `firebase_*`, `sentry_flutter`, `amplitude`, `google_mobile_ads`, `appsflyer`, `facebook_*`, `AdvertisingIdClient`/`ATTrackingManager` (check de CI rompe el build). `google_fonts` con `allowRuntimeFetching = false` + fuentes empaquetadas (sin fonts remotas).
- **Modelo de fecha v1 (premisa 3):** "solo fuente pública". `Estimada` dormido. XIII bajo demanda (Plan 3 lo expone en UI; aquí no).
- **Principios (§0.1-G):** SOLID (DIP: UI/aplicación dependen de interfaces de dominio + providers, no de `drift`/`http`), DRY con criterio (YAGNI + regla de tres), TDD.

---

## Estructura de archivos (este plan)

```
.github/workflows/ci.yml                       # gate: flutter test + check de deps prohibidas
assets/fonts/Fraunces/*.ttf  assets/fonts/SpaceGrotesk/*.ttf   # fuentes self-host
lib/
├── data/
│   ├── local/app_database.dart      # +tabla AppMeta + guardarMeta/leerMeta (modificar)
│   ├── remote/worker_api.dart        # +fetchAllRaw({etag}) decode único (modificar)
│   └── repositories/
│       ├── calendario_repository_impl.dart   # +PrefsRepo, +AppMeta, +versión remota (modificar)
│       ├── worker_remota.dart        # FuenteRemota real (envuelve WorkerApi)
│       └── bundle_semilla.dart       # FuenteSemilla real (envuelve SeedLoader)
├── core/di/providers.dart            # providers raíz Riverpod (db, http, prefs, repos, controllers)
├── design/
│   ├── tokens.dart                   # C (colores), AppType, Space, Radii, Dur, Curves
│   ├── theme.dart                    # ThemeData dark/light + AppStateColors (ThemeExtension)
│   └── widgets/
│       ├── estado_fecha_chip.dart    # icono+etiqueta+color, mergeSemantics
│       ├── contador_regresivo.dart   # número tabular + Semantics liveRegion
│       ├── chip_fuente_publica.dart  # "Fuente pública: MEF" (texto, nunca logo)
│       ├── ribbon_no_oficial.dart    # barra slim persistente, Semantics, 48dp hit
│       └── card_proximo_pago.dart    # póster-lima (Publicada) / neutro punteado (Pendiente)
├── application/
│   ├── home_controller.dart          # AsyncNotifier<ProximoPago?> (null = sin favorito)
│   └── favorito_controller.dart      # set/clear "mi institución" (persistido)
├── features/
│   ├── home/home_screen.dart         # estados: cargando/sin-favorito/dato/sin-internet/desactualizado
│   ├── favorito/selector_institucion.dart   # sheet con buscador (mínimo)
│   └── onboarding/disclaimer_gate.dart      # disclaimer "no oficial" bloqueante 1er uso
└── main.dart                         # bootstrap: tz, ProviderScope, MaterialApp, tema, locale es
test espeja lib/ (widget tests con ProviderScope overrides + unit tests de tokens/repo)
```

> Nota de prefs: `PrefsLocal` (Plan 1) solo guarda primitivos. Este plan agrega claves `manifestJson` y `ultimaRemoteVersion` vía la tabla **`AppMeta`** de drift (no prefs), porque el manifest es estructurado y vive junto a los datos.

---

### Task 1: Tabla `AppMeta` (persistir manifest + versión remota) [costura #3]

**Files:**
- Modify: `lib/data/local/app_database.dart`
- Test: `test/data/local/app_meta_test.dart`

**Interfaces:**
- Produces (en `AppDatabase`): `Future<void> guardarMeta(String clave, String valor)`, `Future<String?> leerMeta(String clave)`. Claves usadas luego: `'manifestJson'`, `'ultimaRemoteVersion'`.

- [ ] **Step 1: Escribir el test**

Create `test/data/local/app_meta_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/data/local/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('guardarMeta/leerMeta hace upsert por clave', () async {
    expect(await db.leerMeta('manifestJson'), isNull);
    await db.guardarMeta('manifestJson', '{"data_version":1}');
    expect(await db.leerMeta('manifestJson'), '{"data_version":1}');
    await db.guardarMeta('manifestJson', '{"data_version":2}'); // overwrite
    expect(await db.leerMeta('manifestJson'), '{"data_version":2}');
  });
}
```

- [ ] **Step 2: Ejecutar el test (debe fallar)**

Run: `flutter test test/data/local/app_meta_test.dart`
Expected: FAIL — `guardarMeta`/`leerMeta` no existen.

- [ ] **Step 3: Agregar la tabla + métodos**

En `lib/data/local/app_database.dart`, agregar la tabla (junto a las otras) y registrarla en `@DriftDatabase`:
```dart
class AppMeta extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();
  @override
  Set<Column> get primaryKey => {clave};
}
```
Cambiar la anotación a `@DriftDatabase(tables: [Calendario, GruposEntidades, XiiiMesT, AppMeta])` y, dentro de la clase, agregar:
```dart
Future<void> guardarMeta(String clave, String valor) =>
    into(appMeta).insertOnConflictUpdate(AppMetaCompanion.insert(clave: clave, valor: valor));

Future<String?> leerMeta(String clave) async {
  final q = select(appMeta)..where((t) => t.clave.equals(clave));
  final row = await q.getSingleOrNull();
  return row?.valor;
}
```

- [ ] **Step 4: Regenerar codegen y correr el test**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/data/local/app_meta_test.dart`
Expected: codegen OK; test PASS. (Bump `schemaVersion` a `2` en `AppDatabase` ya que cambió el esquema.)

- [ ] **Step 5: Commit**

```bash
git add lib/data/local/app_database.dart lib/data/local/app_database.g.dart test/data/local/app_meta_test.dart
git commit -m "feat(data): tabla AppMeta (persistir manifest + versión remota)"
```

---

### Task 2: `fetchAllRaw` en `WorkerApi` (decode único de /v1/all) [costura #1]

**Files:**
- Modify: `lib/data/remote/worker_api.dart`, `lib/data/remote/dto.dart`
- Test: `test/data/remote/worker_api_test.dart` (agregar casos)

**Interfaces:**
- Produces: `class RawAll { final bool notModified; final String? etag; final Map<String,dynamic>? json; }` y `Future<RawAll> WorkerApi.fetchAllRaw({String? etag})`. El repo decodifica `json` con los mappers + siglas (único hogar del decode). El `fetchAll` previo (que construía entidades con siglas vacías) se **elimina** junto con su test.

- [ ] **Step 1: Reemplazar los tests de fetchAll por tests de fetchAllRaw**

En `test/data/remote/worker_api_test.dart`, reemplazar los dos tests `fetchAll ...` por:
```dart
  test('fetchAllRaw envía If-None-Match y maneja 304', () async {
    final client = MockClient((req) async {
      expect(req.headers['If-None-Match'], '"v3"');
      return http.Response('', 304);
    });
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final r = await api.fetchAllRaw(etag: '"v3"');
    expect(r.notModified, isTrue);
    expect(r.json, isNull);
  });

  test('fetchAllRaw 200 devuelve json crudo + etag', () async {
    final body = {'manifest': {'data_version': 3}, 'calendario': [], 'grupos_entidades': [], 'xiii_mes': []};
    final client = MockClient((req) async {
      expect(req.headers.containsKey('If-None-Match'), isFalse); // §0.1-E23: sin etag, sin header
      return http.Response(jsonEncode(body), 200, headers: {'etag': '"v3"'});
    });
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final r = await api.fetchAllRaw();
    expect(r.notModified, isFalse);
    expect(r.etag, '"v3"');
    expect((r.json!['manifest'] as Map)['data_version'], 3);
  });
```
(Conservar el test de `versionCheck`.)

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/data/remote/worker_api_test.dart`
Expected: FAIL — `fetchAllRaw`/`RawAll` no existen.

- [ ] **Step 3: Implementar `RawAll` + `fetchAllRaw`, eliminar el `fetchAll`/`AllPayload` viejos**

En `lib/data/remote/dto.dart`: eliminar `AllPayload` y `AllResponse`; agregar:
```dart
class RawAll {
  final bool notModified;
  final String? etag;
  final Map<String, dynamic>? json;
  const RawAll({required this.notModified, this.etag, this.json});
}
```
(Conservar `VersionInfo`.) En `lib/data/remote/worker_api.dart`, reemplazar `fetchAll` por:
```dart
Future<RawAll> fetchAllRaw({String? etag}) async {
  final r = await _client.get(
    Uri.parse('$baseUrl/v1/all'),
    headers: {if (etag != null) 'If-None-Match': etag},
  );
  if (r.statusCode == 304) return const RawAll(notModified: true);
  final j = jsonDecode(r.body) as Map<String, dynamic>;
  return RawAll(notModified: false, etag: r.headers['etag'], json: j);
}
```
Quitar de `worker_api.dart` los imports de `mappers.dart`/entidades si ya no se usan (el decode lo hace el repo).

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/data/remote/worker_api_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/data/remote/ test/data/remote/worker_api_test.dart
git commit -m "feat(data): WorkerApi.fetchAllRaw (decode único de /v1/all) + assert sin headers identificantes"
```

---

### Task 3: Repo integrado — adaptadores reales + prefs + versión remota persistida [costuras #1–#3]

**Files:**
- Create: `lib/data/repositories/worker_remota.dart`, `lib/data/repositories/bundle_semilla.dart`
- Modify: `lib/data/repositories/calendario_repository_impl.dart`
- Test: `test/data/repositories/calendario_repository_impl_test.dart` (agregar casos), `test/helpers/fakes.dart`

**Interfaces:**
- Consumes: `WorkerApi`, `SeedLoader`, `AppDatabase.guardarMeta/leerMeta`, `PrefsRepository`.
- Produces:
  - `class WorkerRemota implements FuenteRemota { WorkerRemota(this._api); }` con `versionRemota()` → `_api.versionCheck().dataVersion`, `descargarSiCambio(etag)` → `_api.fetchAllRaw(etag:etag).json`.
  - `class BundleSemilla implements FuenteSemilla { BundleSemilla(this._loader); }` con `allJson()` (parsea `SeedLoader.allJson()`), `siglas()` (parsea `SeedLoader.siglasJson()` con `cargarSiglas`).
  - `CalendarioRepositoryImpl` gana parámetro `required PrefsRepository prefs`; persiste/lee `manifestJson` + `ultimaRemoteVersion` en `AppMeta`; `proximoPago` usa la **versión remota persistida** (no la local).

- [ ] **Step 1: Escribir los tests nuevos (persistencia entre "sesiones" + versión remota)**

En `test/data/repositories/calendario_repository_impl_test.dart`, agregar (usa una `PrefsRepository` fake; ver Step 3 para crearla en fakes.dart):
```dart
  test('persiste manifest: una segunda instancia sobre la misma DB no re-descarga', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final prefs = FakePrefs();
    final ahora = () => DateTime.utc(2026, 7, 1, 17, 0);
    final r1 = CalendarioRepositoryImpl(db: db, prefs: prefs,
      api: FakeWorkerApi.conActualizacion(local: 1, remote: 2, cambiaFechaG3: true),
      seed: FakeSeed.dataset2026(), ahora: ahora);
    await r1.asegurarHidratado();
    final s1 = await r1.sincronizar();
    expect(s1.descargo, isTrue);
    expect(r1.manifestActual.dataVersion, 2);

    // "Reinicio": nueva instancia, misma DB, remoto ya en 2.
    final r2 = CalendarioRepositoryImpl(db: db, prefs: prefs,
      api: FakeWorkerApi.sinCambios(version: 2),
      seed: FakeSeed.dataset2026(), ahora: ahora);
    await r2.asegurarHidratado();
    expect(r2.manifestActual.dataVersion, 2); // ← leído de AppMeta, NO de la semilla (v1)
    final s2 = await r2.sincronizar();
    expect(s2.descargo, isFalse); // no re-descarga
    await db.close();
  });

  test('proximoPago usa la versión REMOTA persistida para derivar Desactualizada', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final prefs = FakePrefs();
    final repo = CalendarioRepositoryImpl(db: db, prefs: prefs,
      api: FakeWorkerApi.sinCambios(version: 5), // remoto 5 > local 1
      seed: FakeSeed.dataset2026(), ahora: () => DateTime.utc(2027, 1, 1, 17, 0)); // sin fecha futura
    await repo.asegurarHidratado();
    await repo.sincronizar(); // registra ultimaRemoteVersion=5 (no baja: fake no trae payload nuevo)
    final pp = await repo.proximoPago(SeleccionCategoria(Categoria.grupo3));
    expect(pp.estado, EstadoFecha.desactualizada); // remota(5) > local => accionable
    await db.close();
  });
```
> Ajustar `FakeWorkerApi.sinCambios` para que `descargarSiCambio` devuelva `null` aunque la versión sea mayor (simula 304/no-payload), de modo que `sincronizar` registre la versión remota sin aplicar. Ver Step 3.

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/data/repositories/calendario_repository_impl_test.dart`
Expected: FAIL — falta `prefs`, `FakePrefs`, persistencia.

- [ ] **Step 3: Adaptadores + repo + fakes**

Create `lib/data/repositories/worker_remota.dart`:
```dart
import '../remote/worker_api.dart';
import 'calendario_repository_impl.dart';

class WorkerRemota implements FuenteRemota {
  WorkerRemota(this._api);
  final WorkerApi _api;
  @override
  Future<int> versionRemota() async => (await _api.versionCheck()).dataVersion;
  @override
  Future<Map<String, dynamic>?> descargarSiCambio(String? etag) async =>
      (await _api.fetchAllRaw(etag: etag)).json;
}
```

Create `lib/data/repositories/bundle_semilla.dart`:
```dart
import 'dart:convert';
import '../seed/seed_loader.dart';
import '../mappers.dart';
import 'calendario_repository_impl.dart';

class BundleSemilla implements FuenteSemilla {
  BundleSemilla(this._loader);
  final SeedLoader _loader;
  @override
  Future<Map<String, dynamic>> allJson() async =>
      jsonDecode(await _loader.allJson()) as Map<String, dynamic>;
  @override
  Future<Map<String, List<String>>> siglas() async =>
      cargarSiglas(jsonDecode(await _loader.siglasJson()) as Map<String, dynamic>);
}
```

Modify `lib/data/repositories/calendario_repository_impl.dart`:
- Add field `final PrefsRepository prefs;` (import `../../domain/repositories/prefs_repository.dart`) and `required this.prefs` in the constructor.
- Add `import 'dart:convert';` and `import '../mappers.dart';` (manifestFromJson) — already importing mappers.
- Track remote version: add `int _ultimaRemoteVersion = 0;`.
- Replace `asegurarHidratado` body with:
```dart
  @override
  Future<void> asegurarHidratado() async {
    _siglas = await seed.siglas();
    final metaManifest = await db.leerMeta('manifestJson');
    final yaHay = (await db.todas()).isNotEmpty;
    if (yaHay && metaManifest != null) {
      _manifest = manifestFromJson(jsonDecode(metaManifest) as Map<String, dynamic>);
    } else {
      final j = await seed.allJson();
      _manifest = manifestFromJson(j['manifest'] as Map<String, dynamic>);
      if (!yaHay) await _aplicarPayload(j);
    }
    _ultimaRemoteVersion =
        int.tryParse(await db.leerMeta('ultimaRemoteVersion') ?? '') ?? _manifest!.dataVersion;
  }
```
- In `_aplicarPayload`, after writing rows, persist the manifest: add at the end
```dart
    await db.guardarMeta('manifestJson', jsonEncode(j['manifest']));
```
- In `sincronizar`, after learning `remote`, persist it, and on download keep remote as ultima:
```dart
  @override
  Future<SyncResultado> sincronizar() async {
    final local = _manifest!.dataVersion;
    final remote = await api.versionRemota();
    _ultimaRemoteVersion = remote;
    await db.guardarMeta('ultimaRemoteVersion', '$remote');
    if (remote <= local) {
      return SyncResultado(descargo: false, dataVersion: local, cambios: const []);
    }
    final j = await api.descargarSiCambio('"v$local"');
    if (j == null) {
      return SyncResultado(descargo: false, dataVersion: local, cambios: const []);
    }
    final previas = await db.todas();
    final nuevas = (j['calendario'] as List).map((e) => entradaFromJson(e as Map<String, dynamic>)).toList();
    final cambios = detectarModificadas(previas: previas, nuevas: nuevas, desdeVersion: local);
    await _aplicarPayload(j);
    return SyncResultado(descargo: true, dataVersion: remote, cambios: cambios);
  }
```
- In `proximoPago`, use the persisted remote version:
```dart
  @override
  Future<ProximoPago> proximoPago(Seleccion seleccion) async {
    final entradas = await db.entradasDeCategoria(seleccion.categoria);
    return calcularProximoPago(
      entradasDeCategoria: entradas, seleccion: seleccion,
      manifest: _manifest!, remoteDataVersion: _ultimaRemoteVersion, ahora: _ahora());
  }
```

In `test/helpers/fakes.dart`, add:
```dart
import 'package:cuando_pagan/domain/entities/prefs_usuario.dart';
import 'package:cuando_pagan/domain/repositories/prefs_repository.dart';

class FakePrefs implements PrefsRepository {
  PrefsUsuario _p = const PrefsUsuario();
  @override
  Future<PrefsUsuario> cargar() async => _p;
  @override
  Future<void> guardar(PrefsUsuario prefs) async => _p = prefs;
}
```
And change `FakeWorkerApi.sinCambios` so `descargarSiCambio` returns `null` (no payload) even when version is higher — it already returns `_payload` which is null for `sinCambios`. Confirm `sinCambios(version: N)` sets `_payload = null`. (No change needed if so.)

- [ ] **Step 4: Update existing repo tests to pass `prefs:`**

The two Plan-1 repo tests construct `CalendarioRepositoryImpl(...)` without `prefs`. Add `prefs: FakePrefs()` to both so they compile.

- [ ] **Step 5: Correr y verificar**

Run: `flutter test test/data/repositories/calendario_repository_impl_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/data/repositories/ lib/data/local/ test/data/repositories/ test/helpers/fakes.dart
git commit -m "feat(data): adaptadores reales + persistir manifest/versión remota + threading de versión a proximoPago (costuras #1-3)"
```

---

### Task 4: Providers Riverpod (DI)

**Files:**
- Create: `lib/core/di/providers.dart`
- Test: `test/core/di/providers_test.dart`

**Interfaces:**
- Produces (todos `Provider`/`FutureProvider` de `package:flutter_riverpod`):
  - `httpClientProvider` → `http.Client`
  - `appDatabaseProvider` → `AppDatabase`
  - `seedLoaderProvider` → `SeedLoader`
  - `prefsProvider` → `FutureProvider<PrefsRepository>` (crea `PrefsLocal(await SharedPreferences.getInstance())`)
  - `calendarioRepoProvider` → `FutureProvider<CalendarioRepository>` (compone db+adapters+prefs y llama `asegurarHidratado()`)

- [ ] **Step 1: Test (overrides resuelven el grafo)**

Create `test/core/di/providers_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/core/di/providers.dart';
import 'package:cuando_pagan/data/local/app_database.dart';
import 'package:cuando_pagan/core/time/tz.dart';

void main() {
  setUpAll(initZonaPanama);
  test('calendarioRepoProvider compone e hidrata el repo', () async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
    ]);
    addTearDown(container.dispose);
    final repo = await container.read(calendarioRepoProvider.future);
    expect(repo.manifestActual.dataVersion, greaterThan(0)); // hidrató desde la semilla empacada
  });
}
```
> Este test carga la semilla real vía `rootBundle`, así que requiere `TestWidgetsFlutterBinding.ensureInitialized()` — agrégalo al inicio de `main()` antes de `setUpAll`.

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/core/di/providers_test.dart`
Expected: FAIL — `providers.dart` no existe.

- [ ] **Step 3: Implementar los providers**

Create `lib/core/di/providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/app_database.dart';
import '../../data/local/prefs_local.dart';
import '../../data/remote/worker_api.dart';
import '../../data/seed/seed_loader.dart';
import '../../data/repositories/bundle_semilla.dart';
import '../../data/repositories/worker_remota.dart';
import '../../data/repositories/calendario_repository_impl.dart';
import '../../domain/repositories/calendario_repository.dart';
import '../../domain/repositories/prefs_repository.dart';
import '../constants/umbrales.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final seedLoaderProvider = Provider<SeedLoader>((ref) => SeedLoader());

final prefsProvider = FutureProvider<PrefsRepository>((ref) async =>
    PrefsLocal(await SharedPreferences.getInstance()));

final calendarioRepoProvider = FutureProvider<CalendarioRepository>((ref) async {
  final prefs = await ref.watch(prefsProvider.future);
  final repo = CalendarioRepositoryImpl(
    db: ref.watch(appDatabaseProvider),
    api: WorkerRemota(WorkerApi(ref.watch(httpClientProvider), baseUrl: kWorkerBaseUrl)),
    seed: BundleSemilla(ref.watch(seedLoaderProvider)),
    prefs: prefs,
  );
  await repo.asegurarHidratado();
  return repo;
});
```

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/core/di/providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/di/ test/core/di/
git commit -m "feat(di): providers Riverpod (db, http, prefs, repo hidratado)"
```

---

### Task 5: Design tokens (color/tipografía/espaciado/motion) con test de contraste

**Files:**
- Create: `lib/design/tokens.dart`
- Test: `test/design/tokens_contraste_test.dart`

**Interfaces:**
- Produces: clase `C` (colores dark/light como `Color`), `AppType` (TextStyle base sizes/weights), `Space` (doubles), `Radii` (`BorderRadius`), `Dur` (`Duration`), `Curves` propios. Pares de estado: `C.stPublishedDark/Light`, `stPendingDark/Light`, `stModifiedDark/Light` (light `#8A5A00`), `stStaleDark/Light`, `stEstimatedDark/Light`. Acento `C.accent` (`#C6F647`), `C.onAccent` (`#0B0B0C`), foco `C.focusOnLima` (`#0B0B0C`).

- [ ] **Step 1: Test de contraste (la dirección dark-bold no rompe WCAG)**

Create `test/design/tokens_contraste_test.dart`:
```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/design/tokens.dart';

double _lum(Color c) {
  // Flutter 3.41+: usar .r/.g/.b (0..1), no .red/.green/.blue (deprecados → flutter analyze falla).
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}
double ratio(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  test('texto esencial cumple AA (>=4.5) en dark y light', () {
    expect(ratio(C.textHiDark, C.canvasDark), greaterThanOrEqualTo(4.5));
    expect(ratio(C.textMidDark, C.surface1Dark), greaterThanOrEqualTo(4.5));
    expect(ratio(C.textHiLight, C.canvasLight), greaterThanOrEqualTo(4.5));
  });
  test('tinta sobre lima cumple AA (la card póster)', () {
    expect(ratio(C.onAccent, C.accent), greaterThanOrEqualTo(4.5));
  });
  test('etiqueta state.modified light corregida (>=4.5 sobre surface2 light)', () {
    expect(ratio(C.stModifiedLight, C.surface2Light), greaterThanOrEqualTo(4.5));
  });
  test('anillo de foco oscuro contrasta >=3 contra la superficie lima', () {
    expect(ratio(C.focusOnLima, C.accent), greaterThanOrEqualTo(3.0));
  });
}
```

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/design/tokens_contraste_test.dart`
Expected: FAIL — `tokens.dart` no existe.

- [ ] **Step 3: Implementar tokens**

Create `lib/design/tokens.dart`:
```dart
import 'package:flutter/material.dart';

/// Tokens de color. Dark-first; los `*Light` son la variante clara.
/// NO se usa ColorScheme.fromSeed: estos valores son la fuente de verdad.
abstract final class C {
  // Fondos / superficies
  static const canvasDark = Color(0xFF0B0B0C);
  static const canvasLight = Color(0xFFFAF8F2);
  static const surface1Dark = Color(0xFF141416);
  static const surface1Light = Color(0xFFFFFFFF);
  static const surface2Dark = Color(0xFF1C1C1F);
  static const surface2Light = Color(0xFFF4F1EA);
  // Texto
  static const textHiDark = Color(0xFFF7F5F0);
  static const textHiLight = Color(0xFF14130F);
  static const textMidDark = Color(0xFFC7C5BD);
  static const textMidLight = Color(0xFF46443B);
  static const textMuteDark = Color(0xFF9A9A93);
  static const textMuteLight = Color(0xFF54524A);
  // Acento (lima) — siempre tinta encima
  static const accent = Color(0xFFC6F647);
  static const onAccent = Color(0xFF0B0B0C);
  static const accentOnLight = Color(0xFF46610A); // lima como TEXTO en claro
  static const focusOnLima = Color(0xFF0B0B0C);   // anillo de foco sobre superficies lima
  static const marigold = Color(0xFFF2B441);
  // Estados (dark / light) — §0.1-C12: modified light corregido a #8A5A00
  static const stPublishedDark = Color(0xFF4FC78A);
  static const stPublishedLight = Color(0xFF1E7A4D);
  static const stPendingDark = Color(0xFF9A9A93);
  static const stPendingLight = Color(0xFF6B6A62);
  static const stModifiedDark = Color(0xFFF2A33C);
  static const stModifiedLight = Color(0xFF8A5A00);
  static const stStaleDark = Color(0xFFE5533D);
  static const stStaleLight = Color(0xFFC13D26);
  static const stEstimatedDark = Color(0xFF7C93C7);
  static const stEstimatedLight = Color(0xFF3F5688);
}

abstract final class Space {
  static const x1 = 4.0, x2 = 8.0, x3 = 12.0, x4 = 16.0, x5 = 20.0, x6 = 24.0, x8 = 32.0, x12 = 48.0;
}

abstract final class Radii {
  static const card = BorderRadius.all(Radius.circular(20));
  static const hero = BorderRadius.all(Radius.circular(28));
  static const pill = BorderRadius.all(Radius.circular(999));
  static const input = BorderRadius.all(Radius.circular(14));
}

abstract final class Dur {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 360);
}
```

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/design/tokens_contraste_test.dart`
Expected: PASS (4 tests). Si algún par falla, AJUSTAR el token hasta cumplir (es el lint de contraste — no relajar el umbral).

- [ ] **Step 5: Commit**

```bash
git add lib/design/tokens.dart test/design/tokens_contraste_test.dart
git commit -m "feat(design): tokens de color/espaciado/motion + test de contraste WCAG (lint que rompe el build)"
```

---

### Task 6: Tema (`ThemeData` dark/light + `AppStateColors` + fuentes self-host)

**Files:**
- Create: `lib/design/theme.dart`
- Modify: `pubspec.yaml` (declarar fuentes), `assets/fonts/...` (descargar)
- Test: `test/design/theme_test.dart`

**Interfaces:**
- Produces: `ThemeData appThemeDark()`, `ThemeData appThemeLight()`; `class AppStateColors extends ThemeExtension<AppStateColors>` con `published/pending/modified/stale/estimated` (Color) y `static AppStateColors of(BuildContext)`. Tipografía vía `google_fonts` (Fraunces display, Space Grotesk body), `GoogleFonts.config.allowRuntimeFetching = false`.

- [ ] **Step 1: Descargar y declarar las fuentes (self-host, sin fetch remoto)**

Descargar de Google Fonts (OFL) a `assets/fonts/`: `Fraunces` (pesos 400, 600) y `SpaceGrotesk` (pesos 400, 500, 600, 700). Declarar en `pubspec.yaml` bajo `flutter: fonts:` con familias `Fraunces` y `SpaceGrotesk`, y agregar `assets/fonts/` si hace falta. Verifica que `flutter pub get` resuelve.

- [ ] **Step 2: Test del tema**

Create `test/design/theme_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/design/theme.dart';
import 'package:cuando_pagan/design/tokens.dart';

void main() {
  test('tema dark usa canvas oscuro y primary lima (no morado M3)', () {
    final t = appThemeDark();
    expect(t.scaffoldBackgroundColor, C.canvasDark);
    expect(t.colorScheme.primary, C.accent);
    expect(t.colorScheme.onPrimary, C.onAccent);
    expect(t.useMaterial3, isTrue);
  });
  test('AppStateColors está registrado como ThemeExtension', () {
    final t = appThemeDark();
    final ext = t.extension<AppStateColors>();
    expect(ext, isNotNull);
    expect(ext!.published, C.stPublishedDark);
    expect(ext.modified, C.stModifiedDark);
  });
}
```

- [ ] **Step 3: Ejecutar (debe fallar)**

Run: `flutter test test/design/theme_test.dart`
Expected: FAIL — `theme.dart` no existe.

- [ ] **Step 4: Implementar el tema**

Create `lib/design/theme.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tokens.dart';

@immutable
class AppStateColors extends ThemeExtension<AppStateColors> {
  final Color published, pending, modified, stale, estimated, focusRing;
  const AppStateColors({
    required this.published, required this.pending, required this.modified,
    required this.stale, required this.estimated, required this.focusRing,
  });
  static AppStateColors of(BuildContext c) => Theme.of(c).extension<AppStateColors>()!;
  @override
  AppStateColors copyWith({Color? published, Color? pending, Color? modified, Color? stale, Color? estimated, Color? focusRing}) =>
      AppStateColors(
        published: published ?? this.published, pending: pending ?? this.pending,
        modified: modified ?? this.modified, stale: stale ?? this.stale,
        estimated: estimated ?? this.estimated, focusRing: focusRing ?? this.focusRing);
  @override
  AppStateColors lerp(ThemeExtension<AppStateColors>? other, double t) {
    if (other is! AppStateColors) return this;
    return AppStateColors(
      published: Color.lerp(published, other.published, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      modified: Color.lerp(modified, other.modified, t)!,
      stale: Color.lerp(stale, other.stale, t)!,
      estimated: Color.lerp(estimated, other.estimated, t)!,
      focusRing: Color.lerp(focusRing, other.focusRing, t)!);
  }
}

TextTheme _textTheme(Color hi, Color mid) {
  final display = GoogleFonts.fraunces(color: hi);
  final body = GoogleFonts.spaceGrotesk(
      color: hi, fontFeatures: const [FontFeature.tabularFigures()]);
  return TextTheme(
    displayLarge: display.copyWith(fontSize: 64, height: 0.95, fontWeight: FontWeight.w600, letterSpacing: -1.5),
    displaySmall: display.copyWith(fontSize: 32, fontWeight: FontWeight.w600),
    headlineMedium: display.copyWith(fontSize: 26, fontWeight: FontWeight.w600),
    titleLarge: display.copyWith(fontSize: 22, fontWeight: FontWeight.w600),
    bodyLarge: body.copyWith(fontSize: 18, height: 1.5),
    bodyMedium: body.copyWith(fontSize: 16, height: 1.5, color: mid),
    labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    labelSmall: body.copyWith(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

ThemeData _base({
  required Brightness brightness, required Color canvas, required Color surface,
  required Color textHi, required Color textMid, required AppStateColors states,
}) {
  GoogleFonts.config.allowRuntimeFetching = false; // §0.1-E: sin fonts remotas
  final scheme = ColorScheme(
    brightness: brightness, primary: C.accent, onPrimary: C.onAccent,
    secondary: C.marigold, onSecondary: C.onAccent,
    surface: surface, onSurface: textHi, error: C.stStaleDark, onError: C.onAccent,
  );
  return ThemeData(
    useMaterial3: true, brightness: brightness, colorScheme: scheme,
    scaffoldBackgroundColor: canvas, textTheme: _textTheme(textHi, textMid),
    extensions: [states],
  );
}

ThemeData appThemeDark() => _base(
    brightness: Brightness.dark, canvas: C.canvasDark, surface: C.surface1Dark,
    textHi: C.textHiDark, textMid: C.textMidDark,
    states: const AppStateColors(
      published: C.stPublishedDark, pending: C.stPendingDark, modified: C.stModifiedDark,
      stale: C.stStaleDark, estimated: C.stEstimatedDark, focusRing: C.focusOnLima));

ThemeData appThemeLight() => _base(
    brightness: Brightness.light, canvas: C.canvasLight, surface: C.surface1Light,
    textHi: C.textHiLight, textMid: C.textMidLight,
    states: const AppStateColors(
      published: C.stPublishedLight, pending: C.stPendingLight, modified: C.stModifiedLight,
      stale: C.stStaleLight, estimated: C.stEstimatedLight, focusRing: C.focusOnLima));
```

- [ ] **Step 5: Correr y verificar**

Run: `flutter test test/design/theme_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/design/theme.dart pubspec.yaml assets/fonts/ test/design/theme_test.dart
git commit -m "feat(design): ThemeData dark/light + AppStateColors (ThemeExtension) + fuentes self-host (sin fetch remoto)"
```

---

### Task 7: `EstadoFechaChip` (icono + etiqueta + color, accesible)

**Files:**
- Create: `lib/design/widgets/estado_fecha_chip.dart`
- Test: `test/design/widgets/estado_fecha_chip_test.dart`

**Interfaces:**
- Consumes: `EstadoFecha`, `AppStateColors`.
- Produces: `class EstadoFechaChip extends StatelessWidget { const EstadoFechaChip(this.estado); final EstadoFecha estado; }`. Mapea cada estado a (icono único, etiqueta es, color de estado), envuelto en `MergeSemantics`. Etiquetas: publicada="Publicada", modificada="Modificada", pendiente="Pendiente", desactualizada="Desactualizada", estimada="Estimada".

- [ ] **Step 1: Test (cada estado muestra su etiqueta y un icono; nunca solo color)**

Create `test/design/widgets/estado_fecha_chip_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/design/theme.dart';
import 'package:cuando_pagan/design/widgets/estado_fecha_chip.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';

Widget _host(Widget w) => MaterialApp(theme: appThemeDark(), home: Scaffold(body: Center(child: w)));

void main() {
  testWidgets('cada estado renderiza etiqueta + un icono (no solo color)', (t) async {
    for (final (e, label) in [
      (EstadoFecha.publicada, 'Publicada'),
      (EstadoFecha.pendiente, 'Pendiente'),
      (EstadoFecha.desactualizada, 'Desactualizada'),
    ]) {
      await t.pumpWidget(_host(EstadoFechaChip(e)));
      expect(find.text(label), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    }
  });
}
```

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/design/widgets/estado_fecha_chip_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar el chip**

Create `lib/design/widgets/estado_fecha_chip.dart`:
```dart
import 'package:flutter/material.dart';
import '../tokens.dart';
import '../theme.dart';
import '../../domain/entities/estado_fecha.dart';

class EstadoFechaChip extends StatelessWidget {
  const EstadoFechaChip(this.estado, {super.key});
  final EstadoFecha estado;

  @override
  Widget build(BuildContext context) {
    final s = AppStateColors.of(context);
    final (icon, label, color) = switch (estado) {
      EstadoFecha.publicada => (Icons.check_circle_outline, 'Publicada', s.published),
      EstadoFecha.modificada => (Icons.edit_outlined, 'Modificada', s.modified),
      EstadoFecha.pendiente => (Icons.schedule_outlined, 'Pendiente', s.pending),
      EstadoFecha.desactualizada => (Icons.warning_amber_outlined, 'Desactualizada', s.stale),
      EstadoFecha.estimada => (Icons.timelapse_outlined, 'Estimada', s.estimated),
    };
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x1),
        decoration: BoxDecoration(borderRadius: Radii.pill, border: Border.all(color: color)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: Space.x1),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/design/widgets/estado_fecha_chip_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/estado_fecha_chip.dart test/design/widgets/estado_fecha_chip_test.dart
git commit -m "feat(ui): EstadoFechaChip (icono+etiqueta+color, mergeSemantics)"
```

---

### Task 8: `ContadorRegresivo` + `ChipFuentePublica` + `RibbonNoOficial`

**Files:**
- Create: `lib/design/widgets/contador_regresivo.dart`, `chip_fuente_publica.dart`, `ribbon_no_oficial.dart`
- Test: `test/design/widgets/widgets_basicos_test.dart`

**Interfaces:**
- Produces:
  - `ContadorRegresivo({required int diasRestantes})` — muestra `etiquetaContador(diasRestantes)` con dígitos tabulares; `Semantics(liveRegion:true, label: <misma etiqueta>)`.
  - `ChipFuentePublica({VoidCallback? onTap})` — texto "Fuente pública: MEF" (jamás logo); tappable; Semantics.
  - `RibbonNoOficial({VoidCallback? onTap})` — barra slim "App independiente · No oficial", `Semantics(label:'Aviso: aplicación independiente, no oficial, no afiliada al Gobierno de Panamá')`, hit-target ≥48dp, texto ≥12px.

- [ ] **Step 1: Test**

Create `test/design/widgets/widgets_basicos_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/design/theme.dart';
import 'package:cuando_pagan/design/widgets/contador_regresivo.dart';
import 'package:cuando_pagan/design/widgets/chip_fuente_publica.dart';
import 'package:cuando_pagan/design/widgets/ribbon_no_oficial.dart';

Widget _host(Widget w) => MaterialApp(theme: appThemeDark(), home: Scaffold(body: w));

void main() {
  testWidgets('contador muestra la etiqueta según días', (t) async {
    await t.pumpWidget(_host(const ContadorRegresivo(diasRestantes: 0)));
    expect(find.text('Es hoy'), findsOneWidget);
    await t.pumpWidget(_host(const ContadorRegresivo(diasRestantes: 3)));
    expect(find.text('Faltan 3 días'), findsOneWidget);
  });
  testWidgets('chip fuente es texto, no imagen', (t) async {
    await t.pumpWidget(_host(const ChipFuentePublica()));
    expect(find.textContaining('Fuente pública: MEF'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
  testWidgets('ribbon expone el aviso no-oficial en Semantics', (t) async {
    await t.pumpWidget(_host(const RibbonNoOficial()));
    expect(find.bySemanticsLabel(RegExp('no oficial', caseSensitive: false)), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/design/widgets/widgets_basicos_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar los tres widgets**

Create `lib/design/widgets/contador_regresivo.dart`:
```dart
import 'package:flutter/material.dart';
import '../../domain/logic/contador.dart';

class ContadorRegresivo extends StatelessWidget {
  const ContadorRegresivo({required this.diasRestantes, super.key});
  final int diasRestantes;
  @override
  Widget build(BuildContext context) {
    final txt = etiquetaContador(diasRestantes);
    return Semantics(
      liveRegion: true, label: txt,
      child: ExcludeSemantics(
        child: Text(txt, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}
```

Create `lib/design/widgets/chip_fuente_publica.dart`:
```dart
import 'package:flutter/material.dart';
import '../tokens.dart';

class ChipFuentePublica extends StatelessWidget {
  const ChipFuentePublica({this.onTap, super.key});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: Radii.pill,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.x3, vertical: Space.x2),
        child: Text('Fuente pública: MEF · App no oficial',
            style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
```

Create `lib/design/widgets/ribbon_no_oficial.dart`:
```dart
import 'package:flutter/material.dart';
import '../tokens.dart';

class RibbonNoOficial extends StatelessWidget {
  const RibbonNoOficial({this.onTap, super.key});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Aviso: aplicación independiente, no oficial, no afiliada al Gobierno de Panamá',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity, constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center, color: C.surface2Dark,
          padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x2),
          child: Text('App independiente · No oficial',
              style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/design/widgets/widgets_basicos_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/ test/design/widgets/widgets_basicos_test.dart
git commit -m "feat(ui): ContadorRegresivo + ChipFuentePublica + RibbonNoOficial (Semantics no-oficial, 48dp)"
```

---

### Task 9: `CardProximoPago` (póster-lima / neutro punteado)

**Files:**
- Create: `lib/design/widgets/card_proximo_pago.dart`
- Test: `test/design/widgets/card_proximo_pago_test.dart`

**Interfaces:**
- Consumes: `ProximoPago`, tokens, `EstadoFechaChip`, `ContadorRegresivo`, `ChipFuentePublica`, `intl`.
- Produces: `class CardProximoPago extends StatelessWidget { const CardProximoPago(this.pago, {this.onFuente}); final ProximoPago pago; }`. Si `pago.hayFecha && estado==publicada` → fondo lima (`C.accent`) con tinta `C.onAccent` y la fecha-héroe grande (Fraunces). Si Pendiente/sin fecha → superficie neutra con borde punteado y copy "El MEF aún no publica este período". Siempre incluye `EstadoFechaChip`, `ContadorRegresivo`, `ChipFuentePublica`.

- [ ] **Step 1: Test (Publicada = póster lima con fecha; Pendiente = sin fecha-héroe)**

Create `test/design/widgets/card_proximo_pago_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/design/theme.dart';
import 'package:cuando_pagan/design/tokens.dart';
import 'package:cuando_pagan/design/widgets/card_proximo_pago.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';
import 'package:cuando_pagan/domain/entities/proximo_pago.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';

Widget _host(Widget w) => MaterialApp(theme: appThemeDark(), home: Scaffold(body: Center(child: w)));
final sel = SeleccionCategoria(Categoria.grupo3);

void main() {
  setUpAll(initZonaPanama);

  testWidgets('Publicada: muestra fecha-héroe y estado Publicada', (t) async {
    final pago = ProximoPago(
      entrada: const EntradaCalendario(anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7,
        categoria: Categoria.grupo3, quincena: 1, inicioRegistro: '', cierreRegistro: '',
        retencionAch: '', fechaPago: '2026-07-23'),
      estado: EstadoFecha.publicada, diasRestantes: 22, seleccion: sel,
      fechaPublicacion: '2026-06-26', dataVersion: 1, fuenteUrl: 'https://mef');
    await t.pumpWidget(_host(CardProximoPago(pago)));
    expect(find.text('23'), findsOneWidget); // día-héroe
    expect(find.text('Publicada'), findsOneWidget);
  });

  testWidgets('Pendiente: sin fecha-héroe, copy de pendiente', (t) async {
    final pago = ProximoPago(entrada: null, estado: EstadoFecha.pendiente, diasRestantes: -1,
      seleccion: sel, fechaPublicacion: '2026-06-26', dataVersion: 1, fuenteUrl: 'https://mef');
    await t.pumpWidget(_host(CardProximoPago(pago)));
    expect(find.textContaining('aún no publica'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/design/widgets/card_proximo_pago_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar la card**

Create `lib/design/widgets/card_proximo_pago.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../tokens.dart';
import 'estado_fecha_chip.dart';
import 'contador_regresivo.dart';
import 'chip_fuente_publica.dart';
import '../../domain/entities/estado_fecha.dart';
import '../../domain/entities/proximo_pago.dart';

class CardProximoPago extends StatelessWidget {
  const CardProximoPago(this.pago, {this.onFuente, super.key});
  final ProximoPago pago;
  final VoidCallback? onFuente;

  @override
  Widget build(BuildContext context) {
    final esPoster = pago.hayFecha && pago.estado == EstadoFecha.publicada;
    return esPoster ? _poster(context) : _neutro(context);
  }

  Widget _poster(BuildContext context) {
    final f = pago.entrada!.fechaPagoDate;
    final dia = f.day.toString();
    final restoFecha = DateFormat("MMMM · EEEE", 'es').format(f);
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.x6),
      decoration: const BoxDecoration(color: C.accent, borderRadius: Radii.hero),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text('PRÓXIMO PAGO', style: tt.labelSmall?.copyWith(color: C.onAccent)),
        const SizedBox(height: Space.x2),
        Text(dia, style: tt.displayLarge?.copyWith(color: C.onAccent)),
        Text(restoFecha, style: tt.titleLarge?.copyWith(color: C.onAccent)),
        const SizedBox(height: Space.x3),
        DefaultTextStyle.merge(style: const TextStyle(color: C.onAccent),
          child: ContadorRegresivo(diasRestantes: pago.diasRestantes)),
        const SizedBox(height: Space.x4),
        Row(children: [
          EstadoFechaChip(pago.estado),
          const Spacer(),
          ChipFuentePublica(onTap: onFuente),
        ]),
      ]),
    );
  }

  Widget _neutro(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.x6),
      decoration: BoxDecoration(
        color: C.surface2Dark, borderRadius: Radii.hero,
        border: Border.all(color: C.textMuteDark.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        EstadoFechaChip(pago.estado),
        const SizedBox(height: Space.x3),
        Text('El MEF aún no publica este período.', style: tt.bodyLarge),
        const SizedBox(height: Space.x3),
        ChipFuentePublica(onTap: onFuente),
      ]),
    );
  }
}
```
> Nota: `Color.withValues(alpha:)` requiere Flutter reciente; si la versión instalada no lo trae, usar `.withOpacity(0.4)`.

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/design/widgets/card_proximo_pago_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/design/widgets/card_proximo_pago.dart test/design/widgets/card_proximo_pago_test.dart
git commit -m "feat(ui): CardProximoPago (póster-lima si Publicada / neutro punteado si Pendiente)"
```

---

### Task 10: `FavoritoController` + `HomeController`

**Files:**
- Create: `lib/application/favorito_controller.dart`, `lib/application/home_controller.dart`
- Test: `test/application/home_controller_test.dart`

**Interfaces:**
- Consumes: `calendarioRepoProvider`, `prefsProvider`, `Seleccion`, `ProximoPago`.
- Produces:
  - `favoritoProvider` → `AsyncNotifierProvider<FavoritoController, Seleccion?>`; método `Future<void> fijar(Seleccion)` (persiste token vía prefs), `Future<void> limpiar()`.
  - `homeProvider` → `AsyncNotifierProvider<HomeController, ProximoPago?>`; observa `favoritoProvider`; `null` cuando no hay favorito; si hay, devuelve `repo.proximoPago(seleccion)`.

- [ ] **Step 1: Test (sin favorito → null; con favorito → ProximoPago)**

Create `test/application/home_controller_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/core/di/providers.dart';
import 'package:cuando_pagan/data/local/app_database.dart';
import 'package:cuando_pagan/application/favorito_controller.dart';
import 'package:cuando_pagan/application/home_controller.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initZonaPanama);

  ProviderContainer make() => ProviderContainer(overrides: [
    appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
  ]);

  test('sin favorito el home es null', () async {
    final c = make(); addTearDown(c.dispose);
    final pago = await c.read(homeProvider.future);
    expect(pago, isNull);
  });

  test('al fijar GRUPO 3 el home devuelve un ProximoPago', () async {
    final c = make(); addTearDown(c.dispose);
    await c.read(favoritoProvider.notifier).fijar(SeleccionCategoria(Categoria.grupo3));
    final pago = await c.read(homeProvider.future);
    expect(pago, isNotNull);
    expect(pago!.seleccion.categoria, Categoria.grupo3);
  });
}
```
> El home usa `DateTime.now()` real para "hoy". El test no fija fechas; solo verifica null vs no-null + categoría, así que es robusto al paso del tiempo.

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/application/home_controller_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar los controllers**

Create `lib/application/favorito_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/providers.dart';
import '../domain/entities/seleccion.dart';

final favoritoProvider =
    AsyncNotifierProvider<FavoritoController, Seleccion?>(FavoritoController.new);

class FavoritoController extends AsyncNotifier<Seleccion?> {
  @override
  Future<Seleccion?> build() async {
    final prefs = await ref.watch(prefsProvider.future);
    final repo = await ref.watch(calendarioRepoProvider.future);
    final token = (await prefs.cargar()).seleccionFavorita;
    if (token == null) return null;
    return Seleccion.fromToken(token, await repo.entidades());
  }

  Future<void> fijar(Seleccion sel) async {
    final prefs = await ref.read(prefsProvider.future);
    final actual = await prefs.cargar();
    await prefs.guardar(actual.copyWith(seleccionFavorita: sel.toToken()));
    state = AsyncData(sel);
  }
}
```

Create `lib/application/home_controller.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/di/providers.dart';
import 'favorito_controller.dart';
import '../domain/entities/proximo_pago.dart';

final homeProvider =
    AsyncNotifierProvider<HomeController, ProximoPago?>(HomeController.new);

class HomeController extends AsyncNotifier<ProximoPago?> {
  @override
  Future<ProximoPago?> build() async {
    final sel = await ref.watch(favoritoProvider.future);
    if (sel == null) return null;
    final repo = await ref.watch(calendarioRepoProvider.future);
    return repo.proximoPago(sel);
  }
}
```

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/application/home_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/application/ test/application/
git commit -m "feat(app): FavoritoController + HomeController (Riverpod AsyncNotifier)"
```

---

### Task 11: `SelectorInstitucion` (sheet con buscador mínimo)

**Files:**
- Create: `lib/features/favorito/selector_institucion.dart`
- Test: `test/features/selector_institucion_test.dart`

**Interfaces:**
- Consumes: `calendarioRepoProvider`, `buscarEntidades`, `favoritoProvider`, `Entidad`/`Seleccion`.
- Produces: `class SelectorInstitucion extends ConsumerStatefulWidget` — lista de entidades filtrable por texto (usa `buscarEntidades`); tocar una llama `favoritoProvider.notifier.fijar(SeleccionEntidad(e))` y cierra. Incluye un campo de búsqueda. Targets ≥48dp.

- [ ] **Step 1: Test (buscar "MIDES" filtra y seleccionar fija el favorito)**

Create `test/features/selector_institucion_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/core/di/providers.dart';
import 'package:cuando_pagan/data/local/app_database.dart';
import 'package:cuando_pagan/design/theme.dart';
import 'package:cuando_pagan/features/favorito/selector_institucion.dart';
import 'package:cuando_pagan/application/favorito_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initZonaPanama);

  testWidgets('buscar MIDES filtra y seleccionarla fija el favorito', (t) async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
    ]);
    addTearDown(c.dispose);
    await c.read(calendarioRepoProvider.future); // hidratar
    await t.pumpWidget(UncontrolledProviderScope(container: c,
      child: MaterialApp(theme: appThemeDark(), home: const Scaffold(body: SelectorInstitucion()))));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'MIDES');
    await t.pumpAndSettle();
    expect(find.textContaining('Desarrollo Social'), findsOneWidget);
    await t.tap(find.textContaining('Desarrollo Social'));
    await t.pumpAndSettle();
    final sel = c.read(favoritoProvider).value;
    expect(sel?.categoria.wire, 'GRUPO 3');
  });
}
```

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/features/selector_institucion_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar el selector**

Create `lib/features/favorito/selector_institucion.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../design/tokens.dart';
import '../../domain/entities/entidad.dart';
import '../../domain/entities/seleccion.dart';
import '../../domain/search/buscador_entidades.dart';
import '../../application/favorito_controller.dart';

class SelectorInstitucion extends ConsumerStatefulWidget {
  const SelectorInstitucion({super.key});
  @override
  ConsumerState<SelectorInstitucion> createState() => _S();
}

class _S extends ConsumerState<SelectorInstitucion> {
  String _q = '';
  List<Entidad> _universo = const [];

  @override
  void initState() {
    super.initState();
    ref.read(calendarioRepoProvider.future).then((repo) async {
      final es = await repo.entidades();
      if (mounted) setState(() => _universo = es);
    });
  }

  @override
  Widget build(BuildContext context) {
    final res = buscarEntidades(_q, _universo);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(Space.x4),
        child: TextField(
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Buscar institución (ej. MIDES)'),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      Expanded(child: ListView.builder(
        itemCount: res.length,
        itemBuilder: (_, i) {
          final e = res[i];
          return ListTile(
            minVerticalPadding: 14, // ≥48dp
            title: Text(e.display),
            subtitle: Text(e.grupo.display),
            onTap: () async {
              await ref.read(favoritoProvider.notifier).fijar(SeleccionEntidad(e));
              if (context.mounted) Navigator.of(context).maybePop();
            },
          );
        },
      )),
    ]);
  }
}
```

- [ ] **Step 4: Correr y verificar**

Run: `flutter test test/features/selector_institucion_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/favorito/ test/features/selector_institucion_test.dart
git commit -m "feat(ui): SelectorInstitucion (buscador por sigla/nombre, fija el favorito)"
```

---

### Task 12: `HomeScreen` (estados) + `DisclaimerGate` + `main.dart` bootstrap

**Files:**
- Create: `lib/features/home/home_screen.dart`, `lib/features/onboarding/disclaimer_gate.dart`
- Modify: `lib/main.dart`
- Test: `test/features/home_screen_test.dart`

**Interfaces:**
- Consumes: `homeProvider`, `favoritoProvider`, `CardProximoPago`, `RibbonNoOficial`, `SelectorInstitucion`.
- Produces: `HomeScreen` (ConsumerWidget) que pinta: cargando (spinner), sin-favorito (CTA "Elige tu institución" → abre `SelectorInstitucion` en sheet), dato (`CardProximoPago`), error/offline (mensaje no bloqueante). `RibbonNoOficial` SIEMPRE visible (DoD). `DisclaimerGate` muestra el disclaimer bloqueante en el primer uso (lee/escribe `PrefsUsuario.disclaimerAck`). `main()` inicializa tz, envuelve en `ProviderScope`, `MaterialApp` con tema dark/light y locale `es`.

- [ ] **Step 1: Test (sin favorito muestra CTA + ribbon; con favorito muestra la card)**

Create `test/features/home_screen_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/core/di/providers.dart';
import 'package:cuando_pagan/data/local/app_database.dart';
import 'package:cuando_pagan/design/theme.dart';
import 'package:cuando_pagan/features/home/home_screen.dart';
import 'package:cuando_pagan/application/favorito_controller.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initZonaPanama);

  Future<ProviderContainer> hidratado() async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
    ]);
    await c.read(calendarioRepoProvider.future);
    return c;
  }

  Widget host(ProviderContainer c) => UncontrolledProviderScope(container: c,
      child: MaterialApp(theme: appThemeDark(), home: const HomeScreen()));

  testWidgets('sin favorito: CTA de elegir + ribbon no-oficial siempre presente', (t) async {
    final c = await hidratado(); addTearDown(c.dispose);
    await t.pumpWidget(host(c));
    await t.pumpAndSettle();
    expect(find.textContaining('institución'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('no oficial', caseSensitive: false)), findsOneWidget);
  });

  testWidgets('con favorito: muestra la CardProximoPago', (t) async {
    final c = await hidratado(); addTearDown(c.dispose);
    await c.read(favoritoProvider.notifier).fijar(SeleccionCategoria(Categoria.grupo3));
    await t.pumpWidget(host(c));
    await t.pumpAndSettle();
    expect(find.byType(Card), findsNothing); // usamos Container, no Card de Material
    expect(find.textContaining('Fuente pública'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar (debe fallar)**

Run: `flutter test test/features/home_screen_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar HomeScreen + DisclaimerGate + main.dart**

Create `lib/features/home/home_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/home_controller.dart';
import '../../application/favorito_controller.dart';
import '../../design/tokens.dart';
import '../../design/widgets/card_proximo_pago.dart';
import '../../design/widgets/ribbon_no_oficial.dart';
import '../favorito/selector_institucion.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _abrirSelector(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.85, child: SelectorInstitucion()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorito = ref.watch(favoritoProvider);
    final home = ref.watch(homeProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const RibbonNoOficial(),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(Space.x5),
            child: Center(child: switch ((favorito, home)) {
              (AsyncData(value: null), _) => _sinFavorito(context),
              (_, AsyncData(value: final p?)) => CardProximoPago(p),
              (_, AsyncError()) => const Text('No pudimos cargar. Revisa tu conexión.'),
              _ => const CircularProgressIndicator(),
            }),
          )),
        ]),
      ),
    );
  }

  Widget _sinFavorito(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min, children: [
      Text('¿Qué calendario te interesa?',
          style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
      const SizedBox(height: Space.x4),
      FilledButton(onPressed: () => _abrirSelector(context),
          child: const Text('Elige tu institución o grupo')),
    ]);
}
```

Create `lib/features/onboarding/disclaimer_gate.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/providers.dart';
import '../../design/tokens.dart';

/// Envuelve el home: el primer uso muestra el disclaimer "no oficial" bloqueante.
class DisclaimerGate extends ConsumerStatefulWidget {
  const DisclaimerGate({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<DisclaimerGate> createState() => _G();
}

class _G extends ConsumerState<DisclaimerGate> {
  bool? _ack;
  @override
  void initState() {
    super.initState();
    ref.read(prefsProvider.future).then((p) async {
      final ack = (await p.cargar()).disclaimerAck;
      if (mounted) setState(() => _ack = ack);
    });
  }

  Future<void> _aceptar() async {
    final p = await ref.read(prefsProvider.future);
    await p.guardar((await p.cargar()).copyWith(disclaimerAck: true));
    if (mounted) setState(() => _ack = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_ack == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_ack!) return widget.child;
    return Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(Space.x6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('App independiente y no oficial',
            style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: Space.x4),
        Text('No representa al Gobierno de Panamá ni al MEF. Muestra fechas que el MEF '
             'publica en sus canales oficiales, para consultarlas más fácil.',
            style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
        const SizedBox(height: Space.x6),
        FilledButton(onPressed: _aceptar, child: const Text('Entendido')),
      ]),
    )));
  }
}
```

Replace `lib/main.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/time/tz.dart';
import 'design/theme.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/disclaimer_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initZonaPanama();
  runApp(const ProviderScope(child: CuandoPaganApp()));
}

class CuandoPaganApp extends StatelessWidget {
  const CuandoPaganApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '¿Cuándo Pagan?',
      debugShowCheckedModeBanner: false,
      theme: appThemeLight(),
      darkTheme: appThemeDark(),
      themeMode: ThemeMode.system,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const DisclaimerGate(child: HomeScreen()),
    );
  }
}
```

- [ ] **Step 4: Correr la suite completa + el check de deps**

Run: `flutter test && dart run tool/check_forbidden_deps.dart`
Expected: TODOS los tests PASS; checker imprime OK. Verifica además `flutter analyze` sin errores.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ lib/main.dart test/features/home_screen_test.dart
git commit -m "feat(ui): HomeScreen (estados) + DisclaimerGate bloqueante + bootstrap main.dart (tema dark/light, locale es)"
```

---

### Task 13: Gate de CI (deps prohibidas + suite) [costura #4]

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:** ninguna (infraestructura).

- [ ] **Step 1: Crear el workflow**

Create `.github/workflows/ci.yml`:
```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
jobs:
  flutter:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - name: Gobernanza — sin dependencias de tracking
        run: dart run tool/check_forbidden_deps.dart
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - run: flutter test
```

- [ ] **Step 2: Validar el YAML localmente**

Run: `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML OK"`
Expected: `YAML OK`.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: gate de deps prohibidas + analyze + test en PR/push (costura #4)"
```

---

## Self-Review (cobertura del slice)

**Costuras de Plan 1 resueltas:** #1 decode único (`fetchAllRaw` + repo, Task 2-3) ✅; #2 versión remota hilada a `proximoPago` (Task 3) ✅; #3 manifest persistido en `AppMeta` (Task 1, 3) ✅; #4 gate de CI (Task 13) ✅.

**Spec §A cubierto en este slice:** design system/tokens (Task 5-6, con correcciones §0.1-C12/C13), `EstadoFechaChip`/`ContadorRegresivo`/`ChipFuentePublica`/`RibbonNoOficial`/`CardProximoPago` (Task 7-9), Home con estados cargando/sin-favorito/dato/error (Task 12), selector de institución por siglas (Task 11), disclaimer bloqueante 1er uso + ribbon omnipresente en Semantics (Task 12, DoD). Diferido a Plan 3 (no es hueco): Calendario, Detalle, XIII en UI (+ decisión keyword '13'), Avisos, Fuentes/Acerca de completos, Ajustes/tema-toggle.

**Riesgos a validar en ejecución:** APIs de Riverpod (`AsyncNotifierProvider`, `AsyncData` pattern-matching) y de Flutter (`Color.withValues` vs `.withOpacity`, `GoogleFonts.config.allowRuntimeFetching`) según versión instalada — los implementadores ajustan si la firma difiere; los tests de widget atrapan regresiones. La descarga de las fuentes (Task 6 Step 1) es manual; si falla, degradar temporalmente a `GoogleFonts.fraunces()` runtime y dejar el self-host como pendiente marcado.
