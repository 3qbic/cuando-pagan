# Próximo Pago Inteligente — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El Home muestra el próximo pago de CUALQUIER tipo (quincena o décimo), con ventana "recién pagado" de 6 días y cross-link a la app hermana XIII Mes Panamá.

**Architecture:** Dominio puro nuevo (`EventoPago` + `calcularProximoEvento`) que fusiona `EntradaCalendario` (quincenas) y `XiiiMes` (décimos) y reutiliza `calcularProximoPago` existente como fallback; la UI (`lib/main.dart`) consume el resultado unificado.

**Tech Stack:** Flutter/Dart 3 (sin deps nuevas), flutter_test, url_launcher (ya presente).

**Spec:** `docs/superpowers/specs/2026-08-08-proximo-pago-inteligente-design.md`

## Global Constraints

- Español neutral panameño en todos los copys (tuteo, NUNCA voseo).
- Toda fecha/"hoy" via `hoyPanama(ahora: ahora)` — zona `America/Panamá` fija; `ahora` SIEMPRE inyectable en dominio y tests; jamás `DateTime.now()` directo en dominio.
- `fecha_pago` verbatim: cero corrimiento por fin de semana/feriado.
- Cero dependencias nuevas; cero SDKs de tracking (hay check de CI).
- Gitflow: trabajar en rama `feature/proximo-pago-inteligente` creada desde `develop`.
- Comandos: `flutter test` (suite completa debe quedar verde en cada task), `flutter analyze lib/ test/` sin errores nuevos.
- Los tests de dominio siguen el patrón de `test/domain/logic/proximo_pago_test.dart`: `setUpAll(initZonaPanama)` + helper `fila()` + `ahora` fijo.

---

### Task 1: Dominio — `EventoPago` + núcleo de `calcularProximoEvento`

**Files:**
- Create: `lib/domain/entities/evento_pago.dart`
- Create: `lib/domain/logic/proximo_evento.dart`
- Modify: `lib/core/constants/umbrales.dart` (agregar constante al final)
- Test: `test/domain/logic/proximo_evento_test.dart`

**Interfaces:**
- Consumes (ya existen, NO tocar):
  - `EntradaCalendario{ fechaPago:String ISO, fechaPagoDate:DateTime(UTC 00:00), estado:EstadoFecha, categoria, quincena, inicioRegistro/cierreRegistro/retencionAch:String }` (`lib/domain/entities/entrada_calendario.dart`)
  - `XiiiMes{ anio, semestre, mes, fechaAprox:String ISO, fechaDate:DateTime(UTC 00:00) }` (`lib/domain/entities/xiii_mes.dart`)
  - `ProximoPago` y `calcularProximoPago({required List<EntradaCalendario> entradasDeCategoria, required Seleccion seleccion, required Manifest manifest, required int remoteDataVersion, DateTime? ahora})` (`lib/domain/logic/proximo_pago.dart`)
  - `hoyPanama({DateTime? ahora})` (`lib/core/time/hoy_panama.dart`), `initZonaPanama` (`lib/core/time/tz.dart`)
- Produces (Tasks 2-5 dependen de esto, nombres EXACTOS):
  - `enum TipoEvento { quincena, decimo }`
  - `class EventoPago { DateTime fecha; Set<TipoEvento> tipos; EntradaCalendario? entrada; XiiiMes? xiii; EstadoFecha estado; int diasRestantes; bool get esQuincena; bool get esDecimo; }`
  - `class ResultadoProximoEvento { EventoPago? proximo; EventoPago? recienPasado; ProximoPago base; }`
  - `ResultadoProximoEvento calcularProximoEvento({required List<EntradaCalendario> entradasDeCategoria, required List<XiiiMes> xiii, required Seleccion seleccion, required Manifest manifest, required int remoteDataVersion, DateTime? ahora})`
  - `const int kVentanaRecienPagadoDias = 6;` en `umbrales.dart`

- [ ] **Step 0: Crear rama de trabajo**

```bash
cd /Users/alexisgarcia/proyectos/calendario-pago-pa
git checkout develop && git checkout -b feature/proximo-pago-inteligente
```

- [ ] **Step 1: Escribir los tests que fallan**

Crear `test/domain/logic/proximo_evento_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';
import 'package:cuando_pagan/domain/entities/evento_pago.dart';
import 'package:cuando_pagan/domain/entities/manifest.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';
import 'package:cuando_pagan/domain/entities/xiii_mes.dart';
import 'package:cuando_pagan/domain/logic/proximo_evento.dart';

EntradaCalendario fila(String fechaPago,
        {int q = 1, EstadoFecha estado = EstadoFecha.publicada}) =>
    EntradaCalendario(
        anio: 2026, semestre: 2, mes: 'AGOSTO', mesNum: 8,
        categoria: Categoria.grupo3, quincena: q,
        inicioRegistro: '', cierreRegistro: '', retencionAch: '',
        fechaPago: fechaPago, estado: estado);

XiiiMes xiiiEn(String fecha) =>
    XiiiMes(anio: 2026, semestre: 2, mes: 'AGOSTO', fechaAprox: fecha);

const manifest = Manifest(
    dataVersion: 1, fechaPublicacion: '2026-06-26',
    semestres: ['2026-S1', '2026-S2'], fuente: 'https://mef',
    totalFilas: 120, conteo: {});

final sel = SeleccionCategoria(Categoria.grupo3);

ResultadoProximoEvento calc({
  List<EntradaCalendario> filas = const [],
  List<XiiiMes> xiii = const [],
  DateTime? ahora,
}) =>
    calcularProximoEvento(
        entradasDeCategoria: filas, xiii: xiii, seleccion: sel,
        manifest: manifest, remoteDataVersion: 1, ahora: ahora);

void main() {
  setUpAll(initZonaPanama);
  // 12:00 en Panamá del 1-ago-2026 (UTC-5)
  final ahora = DateTime.utc(2026, 8, 1, 17, 0);

  test('caso real 6-ago: el décimo gana a la quincena', () {
    final r = calc(
        filas: [fila('2026-08-14')], xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.esDecimo, isTrue);
    expect(r.proximo!.esQuincena, isFalse);
    expect(r.proximo!.diasRestantes, 5);
    expect(r.proximo!.xiii, isNotNull);
    expect(r.proximo!.entrada, isNull);
  });

  test('quincena más cercana que el décimo => gana quincena', () {
    final r = calc(
        filas: [fila('2026-08-05')], xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.esQuincena, isTrue);
    expect(r.proximo!.esDecimo, isFalse);
    expect(r.proximo!.diasRestantes, 4);
  });

  test('empate exacto de fechas => un evento con ambos tipos', () {
    final r = calc(
        filas: [fila('2026-08-06')], xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.esQuincena, isTrue);
    expect(r.proximo!.esDecimo, isTrue);
    expect(r.proximo!.tipos, {TipoEvento.quincena, TipoEvento.decimo});
  });

  test('hoy es día de pago => diasRestantes 0 y sin recienPasado', () {
    final r = calc(
        filas: [fila('2026-07-29')], // pasó hace 3 días (dentro de ventana)
        xiii: [xiiiEn('2026-08-01')],
        ahora: ahora);
    expect(r.proximo!.diasRestantes, 0);
    expect(r.recienPasado, isNull); // hoy manda
  });

  test('estado: quincena modificada conserva su estado', () {
    final r = calc(
        filas: [fila('2026-08-10', estado: EstadoFecha.modificada)],
        ahora: ahora);
    expect(r.proximo!.estado, EstadoFecha.modificada);
  });

  test('estado: décimo solo => publicada', () {
    final r = calc(xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.estado, EstadoFecha.publicada);
  });

  test('zona fija: mismo resultado con ahora en otras horas UTC del día', () {
    // 23:30 UTC del 1-ago aún es 18:30 en Panamá => mismo "hoy"
    final r1 = calc(xiii: [xiiiEn('2026-08-06')],
        ahora: DateTime.utc(2026, 8, 1, 23, 30));
    final r2 = calc(xiii: [xiiiEn('2026-08-06')],
        ahora: DateTime.utc(2026, 8, 1, 11, 0));
    expect(r1.proximo!.diasRestantes, r2.proximo!.diasRestantes);
  });
}
```

- [ ] **Step 2: Correr y verificar que FALLA**

Run: `flutter test test/domain/logic/proximo_evento_test.dart`
Expected: FAIL — "Target of URI doesn't exist ... evento_pago.dart / proximo_evento.dart".

- [ ] **Step 3: Implementación mínima**

Agregar al FINAL de `lib/core/constants/umbrales.dart`:

```dart
/// Días tras la fecha de pago durante los cuales el Home muestra el aviso
/// "debía pagarse el X" antes de pasar la página al siguiente evento.
const int kVentanaRecienPagadoDias = 6;
```

Crear `lib/domain/entities/evento_pago.dart`:

```dart
import 'entrada_calendario.dart';
import 'estado_fecha.dart';
import 'proximo_pago.dart';
import 'xiii_mes.dart';

/// Un evento de dinero en el timeline del usuario: quincena, décimo, o ambos
/// si caen el mismo día.
enum TipoEvento { quincena, decimo }

class EventoPago {
  final DateTime fecha;             // UTC 00:00 (misma convención del dominio)
  final Set<TipoEvento> tipos;
  final EntradaCalendario? entrada; // non-null si incluye quincena
  final XiiiMes? xiii;              // non-null si incluye décimo
  final EstadoFecha estado;
  final int diasRestantes;          // negativo si ya pasó

  const EventoPago({
    required this.fecha, required this.tipos, this.entrada, this.xiii,
    required this.estado, required this.diasRestantes,
  });

  bool get esQuincena => tipos.contains(TipoEvento.quincena);
  bool get esDecimo => tipos.contains(TipoEvento.decimo);
}

class ResultadoProximoEvento {
  final EventoPago? proximo;      // hoy o futuro más cercano; null si no hay
  final EventoPago? recienPasado; // en [hoy-kVentanaRecienPagadoDias, hoy-1]
  final ProximoPago base;         // fallback Pendiente/Desactualizada + metadatos

  const ResultadoProximoEvento({
    required this.proximo, required this.recienPasado, required this.base,
  });
}
```

Crear `lib/domain/logic/proximo_evento.dart`:

```dart
import '../entities/entrada_calendario.dart';
import '../entities/estado_fecha.dart';
import '../entities/evento_pago.dart';
import '../entities/manifest.dart';
import '../entities/seleccion.dart';
import '../entities/xiii_mes.dart';
import '../../core/constants/umbrales.dart';
import '../../core/time/hoy_panama.dart';
import 'proximo_pago.dart';

/// Fusiona quincenas de la categoría + décimos (universales) y devuelve el
/// próximo evento, el recién pasado (ventana de [kVentanaRecienPagadoDias])
/// y el resultado clásico como fallback/metadatos.
ResultadoProximoEvento calcularProximoEvento({
  required List<EntradaCalendario> entradasDeCategoria,
  required List<XiiiMes> xiii,
  required Seleccion seleccion,
  required Manifest manifest,
  required int remoteDataVersion,
  DateTime? ahora,
}) {
  final hoy = hoyPanama(ahora: ahora);
  final desde = hoy.subtract(const Duration(days: kVentanaRecienPagadoDias));

  // Borradores por fecha exacta (fusiona quincena+décimo del mismo día).
  final porFecha = <DateTime, ({EntradaCalendario? entrada, XiiiMes? xiii})>{};
  for (final e in entradasDeCategoria) {
    final f = e.fechaPagoDate;
    if (f.isBefore(desde)) continue;
    porFecha[f] = (entrada: e, xiii: porFecha[f]?.xiii);
  }
  for (final x in xiii) {
    final f = x.fechaDate;
    if (f.isBefore(desde)) continue;
    porFecha[f] = (entrada: porFecha[f]?.entrada, xiii: x);
  }

  final eventos = porFecha.entries.map((en) {
    final d = en.value;
    return EventoPago(
      fecha: en.key,
      tipos: {
        if (d.entrada != null) TipoEvento.quincena,
        if (d.xiii != null) TipoEvento.decimo,
      },
      entrada: d.entrada,
      xiii: d.xiii,
      // Quincena manda en el estado; décimo solo => publicada (fuente MEF).
      estado: d.entrada?.estado ?? EstadoFecha.publicada,
      diasRestantes: en.key.difference(hoy).inDays,
    );
  }).toList()
    ..sort((a, b) => a.fecha.compareTo(b.fecha));

  EventoPago? proximo;
  for (final e in eventos) {
    if (!e.fecha.isBefore(hoy)) {
      proximo = e;
      break;
    }
  }

  // "Hoy manda": si hoy hay pago no se muestra el aviso de recién pasado.
  EventoPago? recienPasado;
  if (proximo == null || proximo.diasRestantes > 0) {
    for (final e in eventos.reversed) {
      if (e.fecha.isBefore(hoy)) {
        recienPasado = e;
        break;
      }
    }
  }

  final base = calcularProximoPago(
    entradasDeCategoria: entradasDeCategoria,
    seleccion: seleccion,
    manifest: manifest,
    remoteDataVersion: remoteDataVersion,
    ahora: ahora,
  );

  return ResultadoProximoEvento(
      proximo: proximo, recienPasado: recienPasado, base: base);
}
```

- [ ] **Step 4: Correr y verificar que PASA**

Run: `flutter test test/domain/logic/proximo_evento_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Suite completa + analyze**

Run: `flutter test && flutter analyze lib/ test/`
Expected: todo verde; sin errores nuevos de analyze (los `info` pre-existentes de `prefer_const_constructors` en `buscador_entidades_test.dart` no cuentan).

- [ ] **Step 6: Commit**

```bash
git add lib/domain/entities/evento_pago.dart lib/domain/logic/proximo_evento.dart lib/core/constants/umbrales.dart test/domain/logic/proximo_evento_test.dart
git commit -m "feat(domain): EventoPago + calcularProximoEvento — fusiona quincena y décimo"
```

---

### Task 2: Dominio — ventana "recién pagado" y fallback

**Files:**
- Modify: `test/domain/logic/proximo_evento_test.dart` (agregar tests al final del `main()`)
- (La implementación de Task 1 ya debería cubrirlos; si algo falla, corregir `lib/domain/logic/proximo_evento.dart`.)

**Interfaces:**
- Consumes: todo lo de Task 1 (`calc`, `fila`, `xiiiEn`, `calcularProximoEvento`).
- Produces: garantía de comportamiento de `recienPasado` y `base` que la UI (Tasks 3-4) asume.

- [ ] **Step 1: Agregar los tests que faltan del spec (§5.5-§5.7)**

Dentro del `main()` existente, después del último test:

```dart
  test('pago hace 2 días => recienPasado presente Y proximo apunta al siguiente', () {
    final r = calc(
        filas: [fila('2026-08-14')],
        xiii: [xiiiEn('2026-07-30')], // hace 2 días respecto al 1-ago
        ahora: ahora);
    expect(r.recienPasado, isNotNull);
    expect(r.recienPasado!.esDecimo, isTrue);
    expect(r.recienPasado!.diasRestantes, -2);
    expect(r.proximo!.esQuincena, isTrue);
    expect(r.proximo!.diasRestantes, 13);
  });

  test('pago hace exactamente 6 días => todavía dentro de la ventana', () {
    final r = calc(xiii: [xiiiEn('2026-07-26')], ahora: ahora);
    expect(r.recienPasado, isNotNull);
    expect(r.recienPasado!.diasRestantes, -6);
  });

  test('pago hace 7 días => fuera de la ventana, sin aviso', () {
    final r = calc(xiii: [xiiiEn('2026-07-25')], ahora: ahora);
    expect(r.recienPasado, isNull);
  });

  test('sin eventos futuros => proximo null y base delega Pendiente', () {
    final r = calc(filas: [fila('2026-07-20')], ahora: ahora);
    expect(r.proximo, isNull);
    expect(r.base.hayFecha, isFalse);
    expect(r.base.estado, EstadoFecha.pendiente);
  });

  test('dos pasados en ventana => recienPasado es el más reciente', () {
    final r = calc(
        filas: [fila('2026-07-27')], xiii: [xiiiEn('2026-07-30')], ahora: ahora);
    expect(r.recienPasado!.esDecimo, isTrue);
    expect(r.recienPasado!.fecha, DateTime.utc(2026, 7, 30));
  });
```

- [ ] **Step 2: Correr los tests**

Run: `flutter test test/domain/logic/proximo_evento_test.dart`
Expected: PASS (12 tests). Si alguno falla, corregir la lógica de `proximo_evento.dart` SIN romper los de Task 1.

- [ ] **Step 3: Suite completa**

Run: `flutter test`
Expected: todo verde.

- [ ] **Step 4: Commit**

```bash
git add test/domain/logic/proximo_evento_test.dart lib/domain/logic/proximo_evento.dart
git commit -m "test(domain): ventana recién-pagado (6 días), hoy-manda y fallback pendiente"
```

---

### Task 3: UI — Hero unificado (chips de tipo, HOY, anillo del décimo, timeline condicional)

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `calcularProximoEvento(...)`, `ResultadoProximoEvento`, `EventoPago` (Task 1). En `main.dart` ya existen: `HomeTab`, `_HeroCard`, `_ProcesoCard`, `_Ring`, `_EstadoBadge`, `_progreso(entrada, hoy)`, `Dataset.xiii` (ordenado), `hoyPanama()`, `_gold`, `_acc`, `_hi`, `_mid`.
- Produces: `_HeroCard` acepta `ResultadoProximoEvento` (Task 4 le agrega el aviso encima; Task 5 usa `res.proximo!.esDecimo`).

- [ ] **Step 1: Imports y cableado de HomeTab**

En `lib/main.dart` agregar imports (junto a los demás de domain):

```dart
import 'domain/entities/evento_pago.dart';
import 'domain/logic/proximo_evento.dart';
```

En `HomeTab.build`, reemplazar el cálculo y el uso del hero/proceso:

```dart
    final entradas = ds.calendario.where((e) => e.categoria == seleccion.categoria).toList();
    final res = calcularProximoEvento(
      entradasDeCategoria: entradas, xiii: ds.xiii, seleccion: seleccion,
      manifest: ds.manifest, remoteDataVersion: ds.manifest.dataVersion);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        _InstitucionCard(seleccion: seleccion, recordar: recordar, onRecordar: onRecordar, onCambiar: onCambiar),
        const SizedBox(height: 14),
        _HeroCard(res: res),
        if (res.proximo?.entrada != null) ...[
          const SizedBox(height: 14),
          _ProcesoCard(entrada: res.proximo!.entrada!),
        ],
      ],
    );
```

(La llamada previa a `calcularProximoPago` en `HomeTab` se elimina; el import de
`domain/logic/proximo_pago.dart` en `main.dart` puede quedar sin uso — quitarlo si
`flutter analyze` lo marca.)

- [ ] **Step 2: Reescribir `_HeroCard` para `ResultadoProximoEvento`**

Reemplazar la clase `_HeroCard` completa por:

```dart
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.res});
  final ResultadoProximoEvento res;

  @override
  Widget build(BuildContext context) {
    final ev = res.proximo;
    if (ev == null) return _pendiente(context);
    final f = ev.fecha;
    final esHoy = ev.diasRestantes == 0;
    // Progreso del anillo: quincena usa su proceso; décimo usa ventana fija 30d.
    final prog = ev.entrada != null
        ? _progreso(ev.entrada!, hoyPanama())
        : ((30 - ev.diasRestantes) / 30).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF16273C), Color(0xFF0F1B2C)]),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0x2E25E6A4)),
        boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 16))],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(esHoy ? '¡HOY TE TOCA!' : 'PRÓXIMO PAGO',
              style: const TextStyle(fontSize: 11, letterSpacing: 2, color: _acc, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (ev.esQuincena) const _ChipTipo(texto: 'QUINCENA', color: _acc, icono: Icons.payments_outlined),
          if (ev.esQuincena && ev.esDecimo) const SizedBox(width: 6),
          if (ev.esDecimo) const _ChipTipo(texto: 'DÉCIMO', color: _gold, icono: Icons.card_giftcard_rounded),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${f.day}', style: const TextStyle(fontSize: 58, height: .9, fontWeight: FontWeight.w800, color: _hi, letterSpacing: -2)),
              Text('de ${DateFormat('MMMM', 'es').format(f)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: _hi)),
              Text(DateFormat('EEEE', 'es').format(f), style: const TextStyle(fontSize: 13.5, color: _mid)),
            ]),
          ),
          _Ring(dias: ev.diasRestantes, progreso: prog),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          _EstadoBadge(estado: ev.estado),
          const Spacer(),
          InkWell(
            onTap: () => _abrir(_mefFullUrl),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Fuente pública: MEF', style: TextStyle(fontSize: 12, color: _mid, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.north_east, size: 12, color: _mid),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _pendiente(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PRÓXIMO PAGO', style: TextStyle(fontSize: 11, letterSpacing: 2, color: _acc, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        _EstadoBadge(estado: res.base.estado),
        const SizedBox(height: 12),
        const Text('El MEF aún no publica este período.', style: TextStyle(fontSize: 17, color: _hi, height: 1.4)),
        const SizedBox(height: 8),
        const Text('Fuente pública: MEF · App no oficial', style: TextStyle(fontSize: 12, color: _mid)),
      ]),
    );
  }
}

class _ChipTipo extends StatelessWidget {
  const _ChipTipo({required this.texto, required this.color, required this.icono});
  final String texto;
  final Color color;
  final IconData icono;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: .12),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 11, color: color),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8, color: color)),
      ]),
    );
  }
}
```

Nota: el `_Ring` existente ya muestra "HOY" cuando `dias <= 0`; no tocarlo.

- [ ] **Step 3: Verificar**

Run: `flutter analyze lib/main.dart && flutter test`
Expected: sin errores; suite verde (los tests de dominio no tocan UI).

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(ui): hero unificado — chips quincena/décimo, HOY TE TOCA, anillo décimo 30d, timeline condicional"
```

---

### Task 4: UI — aviso "recién pagado"

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `res.recienPasado` (`EventoPago?` con `fecha`, `esDecimo`, `esQuincena`) de Task 3.
- Produces: widget `_AvisoRecienPagado({required EventoPago evento})`.

- [ ] **Step 1: Agregar el widget** (junto a los demás widgets del Home):

```dart
class _AvisoRecienPagado extends StatelessWidget {
  const _AvisoRecienPagado({required this.evento});
  final EventoPago evento;
  @override
  Widget build(BuildContext context) {
    final tipo = evento.esDecimo ? 'el décimo' : 'la quincena';
    final fecha = DateFormat("d 'de' MMMM", 'es').format(evento.fecha);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x14F4C868),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x33F4C868)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.schedule, size: 18, color: _gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Según el calendario, $tipo debía pagarse el $fecha. Si no te ha llegado, recuerda que la fecha es referencial; confírmalo con tu planilla o el MEF.',
            style: const TextStyle(fontSize: 13, color: Color(0xFFD9C79A), height: 1.45),
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 2: Integrarlo en `HomeTab`** — en la lista `children`, entre `_InstitucionCard` y `_HeroCard`:

```dart
        if (res.recienPasado != null) ...[
          const SizedBox(height: 14),
          _AvisoRecienPagado(evento: res.recienPasado!),
        ],
```

- [ ] **Step 3: Verificar**

Run: `flutter analyze lib/main.dart && flutter test`
Expected: limpio y verde.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat(ui): aviso 'recién pagado' con ventana de 6 días (copy referencial, no acusatorio)"
```

---

### Task 5: Cross-link a XIII Mes Panamá (app hermana)

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `_abrir(url)` y `_cardDeco()` existentes; `res.proximo?.esDecimo` (Task 3); `DecimoTab` existente.
- Produces: constante `_xiiiMesPlayUrl`; tarjeta `_CardXiiiMesApp` en la pestaña Décimo; enlace compacto en el Home cuando el evento es décimo.

- [ ] **Step 1: Constante** (junto a `_mefFullUrl`):

```dart
const _xiiiMesPlayUrl = 'https://play.google.com/store/apps/details?id=com.amgd.xiiimespanama';
```

- [ ] **Step 2: Tarjeta en `DecimoTab`** — en el `ListView`, ANTES del texto final "Fechas del décimo según…":

```dart
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _abrir(_xiiiMesPlayUrl),
          child: Container(
            decoration: _cardDeco(borde: const Color(0x33F4C868)),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [Color(0x40F4C868), Color(0x10F4C868)]),
                  border: Border.all(color: const Color(0x55F4C868)),
                ),
                child: const Icon(Icons.calculate_outlined, color: _gold, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('¿Quieres saber cuánto te toca?', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _hi)),
                  SizedBox(height: 2),
                  Text('Calcúlalo con XIII Mes Panamá, nuestra app hermana (también independiente y no oficial).', style: TextStyle(fontSize: 12, color: _mid, height: 1.35)),
                ]),
              ),
              const Icon(Icons.open_in_new, size: 16, color: _mute),
            ]),
          ),
        ),
```

- [ ] **Step 3: Enlace compacto en el Home** — en `HomeTab`, después del bloque de `_ProcesoCard`:

```dart
        if (res.proximo?.esDecimo ?? false) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => _abrir(_xiiiMesPlayUrl),
              icon: const Icon(Icons.calculate_outlined, size: 16, color: _gold),
              label: const Text('¿Cuánto te toca? Calcúlalo con XIII Mes Panamá',
                  style: TextStyle(fontSize: 12.5, color: _gold, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
```

- [ ] **Step 4: Verificar + suite + deps prohibidas**

Run: `flutter analyze lib/main.dart && flutter test && dart run tool/check_forbidden_deps.dart`
Expected: limpio, verde, y el check de deps sigue pasando (es solo un enlace, cero SDKs).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat(ui): cross-link a XIII Mes Panamá (app hermana) en Décimo y en el Home"
```

---

### Task 6: Verificación integral (build web + visual)

**Files:**
- Ninguno nuevo (verificación).

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: build verificado listo para que el orquestador haga el release gitflow (v0.3.0) tras el OK visual del usuario. **El release/deploy NO es parte de esta task** — lo ejecuta el orquestador.

- [ ] **Step 1: Suite completa final**

Run: `flutter test && flutter analyze lib/ test/`
Expected: todo verde (51+ tests: 39 previos + 12 nuevos).

- [ ] **Step 2: Build web**

Run: `flutter build web --release`
Expected: `✓ Built build/web`.

- [ ] **Step 3: Verificación visual (la hace el orquestador con chrome-devtools MCP)**

Servir `build/web` en un puerto nuevo y verificar con el navegador:
1. Con favorita `cat:JUBILADOS` (localStorage `flutter.favorita` = `"cat:JUBILADOS"` JSON-encoded), HOY (8-ago-2026) el Home debe mostrar: **aviso "el décimo debía pagarse el 6 de agosto"** (ventana de 2 días) + hero con la **quincena del 14-15 de agosto** y chip QUINCENA + timeline visible.
2. Pestaña Décimo: la tarjeta de XIII Mes Panamá aparece y el enlace apunta a Play.
3. Cero errores en consola.

- [ ] **Step 4: Commit final de la rama (si hubo ajustes)**

```bash
git add -A && git commit -m "chore: ajustes de verificación integral" || echo "nada que commitear"
```

---

## Self-review (hecho al escribir el plan)

- **Cobertura del spec:** §0-§1 (Tasks 3-4), §2 (Tasks 1-2), §3 UI + cross-link (Tasks 3-5), §4 datos (sin cambios — ninguna task toca pipeline), §5 tests (Tasks 1-2 = 12 casos que cubren los 9 del spec), §6-§7 respetados.
- **Sin placeholders:** todo el código está inline.
- **Consistencia de tipos:** `EventoPago`/`ResultadoProximoEvento`/`calcularProximoEvento` idénticos entre Tasks 1-5; `_ChipTipo`, `_AvisoRecienPagado`, `_xiiiMesPlayUrl` definidos donde se usan.
- **Nota:** el spec §5 caso "empate" y "recienPasado más reciente" están en Tasks 1-2; el caso TZ (§5.9) está en Task 1 Step 1 último test.
