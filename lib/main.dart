import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/text/normalizar.dart';
import 'core/time/hoy_panama.dart';
import 'core/time/tz.dart';
import 'core/constants/umbrales.dart';
import 'data/mappers.dart';
import 'domain/entities/categoria.dart';
import 'domain/entities/entidad.dart';
import 'domain/entities/entrada_calendario.dart';
import 'domain/entities/estado_fecha.dart';
import 'domain/entities/evento_pago.dart';
import 'domain/entities/manifest.dart';
import 'domain/entities/seleccion.dart';
import 'domain/entities/xiii_mes.dart';
import 'domain/logic/proximo_evento.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initZonaPanama();
  await initializeDateFormatting('es');
  runApp(const CuandoPaganApp());
}

// ── Tokens (dirección moderna / oscura / premium) ──
const _bg0 = Color(0xFF070C14);
const _bg1 = Color(0xFF0C1524);
const _surf = Color(0xFF111C2E);
const _surf2 = Color(0xFF16233A);
const _hi = Color(0xFFEEF4F8);
const _mid = Color(0xFF9FB0C3);
const _mute = Color(0xFF6C7C90);
const _line = Color(0x14FFFFFF);
const _acc = Color(0xFF25E6A4);
const _acc2 = Color(0xFF12B98A);
const _gold = Color(0xFFF4C868);
const _danger = Color(0xFFFF6B5A);

const _kFavorita = 'favorita';
const _kDisclaimer = 'disclaimerAck';
const _titular = '3qbic';
const _sitio3qbic = 'https://3qbic.com';
const _repoUrl = 'github.com/3qbic/cuando-pagan';
const _contacto = 'cuandopagan@3qbic.com';
const _mefFullUrl = 'https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/';
const _xiiiMesPlayUrl = 'https://play.google.com/store/apps/details?id=com.amgd.xiiimespanama';

Future<void> _abrir(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

BoxDecoration _cardDeco({Color? color, Color? borde, bool glow = false}) => BoxDecoration(
      gradient: color == null
          ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x0DFFFFFF), Color(0x05FFFFFF)])
          : null,
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borde ?? _line),
      boxShadow: glow
          ? const [BoxShadow(color: Color(0x400CE39A), blurRadius: 40, spreadRadius: -18, offset: Offset(0, 12))]
          : const [BoxShadow(color: Color(0x66000000), blurRadius: 30, spreadRadius: -20, offset: Offset(0, 14))],
    );

class CuandoPaganApp extends StatelessWidget {
  const CuandoPaganApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return MaterialApp(
      title: '¿Cuándo Pagan?',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        scaffoldBackgroundColor: _bg0,
        colorScheme: base.colorScheme.copyWith(primary: _acc, surface: _surf, onSurface: _hi),
        textTheme: base.textTheme.apply(bodyColor: _hi, displayColor: _hi, fontFamily: 'Roboto'),
      ),
      home: const RootPage(),
    );
  }
}

// Fondo con degradado + brillo (premium).
class _Fondo extends StatelessWidget {
  const _Fondo({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_bg1, _bg0]),
      ),
      child: Stack(children: [
        const Positioned(top: -120, right: -80, child: _Glow(color: Color(0x3325E6A4), size: 320)),
        const Positioned(top: -60, left: -100, child: _Glow(color: Color(0x222678FF), size: 300)),
        child,
      ]),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 40)]),
        ),
      );
}

// ───────────────────────── Datos + lógica ─────────────────────────

class Dataset {
  final Manifest manifest;
  final List<EntradaCalendario> calendario;
  final List<Entidad> entidades;
  final List<XiiiMes> xiii;
  Dataset(this.manifest, this.calendario, this.entidades, this.xiii);
}

Future<Dataset> _cargar() async {
  final all = jsonDecode(await rootBundle.loadString('assets/seed/all.json')) as Map<String, dynamic>;
  final siglas = cargarSiglas(jsonDecode(await rootBundle.loadString('assets/data/siglas_entidades.json')) as Map<String, dynamic>);
  final manifest = manifestFromJson(all['manifest'] as Map<String, dynamic>);
  final cal = (all['calendario'] as List).map((e) => entradaFromJson(e as Map<String, dynamic>)).toList();
  final ents = construirEntidades(all['grupos_entidades'] as List, siglas);
  final xiii = (all['xiii_mes'] as List).map((e) => xiiiFromJson(e as Map<String, dynamic>)).toList()
    ..sort((a, b) => a.fechaDate.compareTo(b.fechaDate));
  return Dataset(manifest, cal, ents, xiii);
}

List<Seleccion> _opciones(Dataset ds) {
  final ents = ds.entidades.toList()..sort((a, b) => a.display.compareTo(b.display));
  return [
    SeleccionCategoria(Categoria.jubilados),
    SeleccionCategoria(Categoria.gastosRepresentacion),
    for (final e in ents) SeleccionEntidad(e),
  ];
}

List<Seleccion> _filtrar(String q, List<Seleccion> ops) {
  final n = normalizar(q);
  if (n.isEmpty) return ops;
  return ops.where((s) {
    if (s is SeleccionEntidad) {
      final e = s.entidad;
      return normalizar(e.display).contains(n) || normalizar(e.nombreWire).contains(n) || e.siglas.any((x) => normalizar(x).contains(n));
    }
    return normalizar(s.etiqueta).contains(n);
  }).toList();
}

DateTime? _d(String s) => s.isEmpty ? null : DateTime.parse('${s}T00:00:00Z');

/// Progreso del proceso de pago (0..1) desde inicio_registro hasta fecha_pago.
double _progreso(EntradaCalendario e, DateTime hoy) {
  final ini = _d(e.inicioRegistro) ?? e.fechaPagoDate.subtract(const Duration(days: 15));
  final pago = e.fechaPagoDate;
  final total = pago.difference(ini).inSeconds;
  if (total <= 0) return 1;
  final t = hoy.difference(ini).inSeconds / total;
  return t.clamp(0.0, 1.0);
}

/// Progreso (0..1) del anillo cuando el evento es décimo: ventana fija de
/// [kVentanaAnilloDecimoDias] días antes de la fecha (el XIII no tiene proceso).
double progresoAnilloDecimo(int diasRestantes) =>
    ((kVentanaAnilloDecimoDias - diasRestantes) / kVentanaAnilloDecimoDias)
        .clamp(0.0, 1.0);

/// Subtítulo de una selección: nunca repite la etiqueta.
/// Entidad → "Grupo 3 · MIDES"; Categoría → descriptor genérico.
String _descSeleccion(Seleccion s) {
  if (s is SeleccionEntidad) {
    final sigla = s.entidad.siglas.isNotEmpty ? s.entidad.siglas.first : null;
    return sigla != null ? '${s.categoria.display} · $sigla' : s.categoria.display;
  }
  return 'Categoría del calendario del MEF';
}

// ───────────────────────── Shell + bottom nav ─────────────────────────

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  Dataset? _ds;
  List<Seleccion> _ops = const [];
  Seleccion? _sel;        // institución que se está consultando (persistida o no)
  bool _recordar = true;  // ¿_sel guardada como favorita? (ganchito "recordar")
  bool _cargando = true;
  bool _ack = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ds = await _cargar();
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kFavorita);
    final ack = prefs.getBool(_kDisclaimer) ?? false;
    final sel = token == null ? null : Seleccion.fromToken(token, ds.entidades);
    if (!mounted) return;
    setState(() {
      _ds = ds;
      _ops = _opciones(ds);
      _sel = sel;
      _recordar = sel != null; // si venía persistida, el ganchito arranca marcado
      _ack = ack;
      _cargando = false;
    });
  }

  /// Consultar una institución: se muestra de inmediato. Por defecto se recuerda
  /// (ganchito marcado), así la próxima apertura entra directo.
  Future<void> _consultar(Seleccion s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kFavorita, s.toToken());
    if (mounted) setState(() { _sel = s; _recordar = true; _tab = 0; });
  }

  /// Alternar el ganchito "Recordar esta institución" sin salir de la consulta.
  Future<void> _setRecordar(bool v) async {
    final p = await SharedPreferences.getInstance();
    if (v && _sel != null) {
      await p.setString(_kFavorita, _sel!.toToken());
    } else {
      await p.remove(_kFavorita);
    }
    if (mounted) setState(() => _recordar = v);
  }

  Future<void> _cambiar() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kFavorita);
    if (mounted) setState(() { _sel = null; _recordar = true; });
  }

  Future<void> _aceptar() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kDisclaimer, true);
    if (mounted) setState(() => _ack = true);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    bool nav = false;
    if (_cargando) {
      body = const Center(child: CircularProgressIndicator(color: _acc));
    } else if (!_ack) {
      body = DisclaimerGate(onContinuar: _aceptar);
    } else if (_sel == null) {
      body = OnboardingView(ops: _ops, onConsultar: _consultar);
    } else {
      nav = true;
      body = switch (_tab) {
        1 => CalendarioTab(ds: _ds!, seleccion: _sel!),
        2 => DecimoTab(ds: _ds!),
        3 => const AcercaContenido(),
        _ => HomeTab(ds: _ds!, seleccion: _sel!, recordar: _recordar, onRecordar: _setRecordar, onCambiar: _cambiar),
      };
    }
    return Scaffold(
      body: _Fondo(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(children: [const _Header(), Expanded(child: body)]),
            ),
          ),
        ),
      ),
      bottomNavigationBar: nav ? _BottomNav(index: _tab, onTap: (i) => setState(() => _tab = i)) : null,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 2),
      child: Row(children: [
        const Text('¿Cuándo Pagan?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _hi, letterSpacing: -0.3)),
        const Spacer(),
        Semantics(
          button: true,
          label: 'Aviso: aplicación independiente, no oficial, no afiliada al Gobierno de Panamá. Toca para Acerca de.',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AcercaDeScreen())),
            child: Container(
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(color: const Color(0x1AF4C868), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x47F4C868))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline, size: 13, color: _gold),
                SizedBox(width: 5),
                Text('No oficial', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _gold)),
              ]),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: _mid),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AcercaDeScreen())),
        ),
      ]),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;
  static const _items = [
    (Icons.home_rounded, 'Inicio'),
    (Icons.calendar_month_rounded, 'Calendario'),
    (Icons.card_giftcard_rounded, 'Décimo'),
    (Icons.info_outline_rounded, 'Acerca'),
  ];
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xE60A121E),
        border: Border(top: BorderSide(color: _line)),
      ),
      padding: EdgeInsets.only(top: 10, bottom: 10 + MediaQuery.of(context).padding.bottom),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _items.length; i++)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_items[i].$1, size: 23, color: i == index ? _acc : _mute),
                  const SizedBox(height: 4),
                  Text(_items[i].$2, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: i == index ? _acc : _mute)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Home ─────────────────────────

class HomeTab extends StatelessWidget {
  const HomeTab({required this.ds, required this.seleccion, required this.recordar, required this.onRecordar, required this.onCambiar, super.key});
  final Dataset ds;
  final Seleccion seleccion;
  final bool recordar;
  final ValueChanged<bool> onRecordar;
  final VoidCallback onCambiar;
  @override
  Widget build(BuildContext context) {
    final entradas = ds.calendario.where((e) => e.categoria == seleccion.categoria).toList();
    final res = calcularProximoEvento(
      entradasDeCategoria: entradas, xiii: ds.xiii, seleccion: seleccion,
      manifest: ds.manifest, remoteDataVersion: ds.manifest.dataVersion);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        _InstitucionCard(seleccion: seleccion, recordar: recordar, onRecordar: onRecordar, onCambiar: onCambiar),
        const SizedBox(height: 14),
        if (res.recienPasado != null) ...[
          _AvisoRecienPagado(evento: res.recienPasado!),
          const SizedBox(height: 14),
        ],
        _HeroCard(res: res),
        if (res.proximo?.entrada != null) ...[
          const SizedBox(height: 14),
          _ProcesoCard(entrada: res.proximo!.entrada!),
        ],
        if (res.proximo?.esDecimo ?? false) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => _abrir(_xiiiMesPlayUrl),
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(Icons.calculate_outlined, size: 16, color: _gold),
              label: const Text('¿Cuánto te toca? Calcúlalo con XIII Mes Panamá (app hermana, no oficial)',
                  style: TextStyle(fontSize: 12.5, color: _gold, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }
}

class _InstitucionCard extends StatelessWidget {
  const _InstitucionCard({required this.seleccion, required this.recordar, required this.onRecordar, required this.onCambiar});
  final Seleccion seleccion;
  final bool recordar;
  final ValueChanged<bool> onRecordar;
  final VoidCallback onCambiar;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      child: Column(children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [Color(0x4025E6A4), Color(0x1025E6A4)]),
              border: Border.all(color: const Color(0x5525E6A4)),
            ),
            child: const Icon(Icons.account_balance_rounded, color: _acc, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recordar ? 'MI INSTITUCIÓN' : 'CONSULTANDO',
                  style: const TextStyle(fontSize: 10, letterSpacing: 1.3, color: _mute, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(seleccion.etiqueta, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _hi), maxLines: 2),
              Text(_descSeleccion(seleccion), style: const TextStyle(fontSize: 12, color: _mid)),
            ]),
          ),
          TextButton(
            onPressed: onCambiar,
            style: TextButton.styleFrom(foregroundColor: _acc, backgroundColor: const Color(0x1425E6A4), minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
            child: const Text('Cambiar', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
        const Divider(height: 18, thickness: 1, color: _line),
        // Ganchito "Recordar" (estilo remember-me): guardar es opcional.
        Semantics(
          container: true,
          toggled: recordar,
          label: 'Recordar esta institución',
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onRecordar(!recordar),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(children: [
                Icon(recordar ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 20, color: recordar ? _acc : _mute),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(recordar ? 'Recordar esta institución' : 'No recordar (solo esta vez)',
                      style: TextStyle(fontSize: 13, color: recordar ? _hi : _mid, fontWeight: FontWeight.w500)),
                ),
                Text(recordar ? 'Abre aquí la próxima vez' : 'Preguntará al abrir',
                    style: const TextStyle(fontSize: 11, color: _mute)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

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
        : progresoAnilloDecimo(ev.diasRestantes);
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
          Expanded(
            child: Text(esHoy ? '¡HOY TE TOCA!' : 'PRÓXIMO PAGO',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, letterSpacing: 2, color: _acc, fontWeight: FontWeight.w800)),
          ),
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

class _AvisoRecienPagado extends StatelessWidget {
  const _AvisoRecienPagado({required this.evento});
  final EventoPago evento;
  @override
  Widget build(BuildContext context) {
    final tipo = evento.esDecimo && evento.esQuincena
        ? 'el décimo y la quincena'
        : (evento.esDecimo ? 'el décimo' : 'la quincena');
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

class _Ring extends StatelessWidget {
  const _Ring({required this.dias, required this.progreso});
  final int dias;
  final double progreso;
  @override
  Widget build(BuildContext context) {
    final txt = dias <= 0 ? 'HOY' : '$dias';
    return SizedBox(
      width: 116, height: 116,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(size: const Size(116, 116), painter: _RingPainter(progreso)),
        Container(
          width: 92, height: 92,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF182A40), Color(0xFF0E1929)]),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(txt, style: TextStyle(fontSize: dias <= 0 ? 26 : 36, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
              if (dias > 0) const Text('DÍAS', style: TextStyle(fontSize: 10, color: _mid, letterSpacing: .5)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final bg = Paint()..style = PaintingStyle.stroke..strokeWidth = 11..color = const Color(0x18FFFFFF);
    canvas.drawCircle(c, r, bg);
    final fg = Paint()
      ..style = PaintingStyle.stroke..strokeWidth = 11..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(colors: [_acc2, _acc]).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * p.clamp(0.02, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.p != p;
}

class _ProcesoCard extends StatelessWidget {
  const _ProcesoCard({required this.entrada});
  final EntradaCalendario entrada;
  @override
  Widget build(BuildContext context) {
    final hoy = hoyPanama();
    final pasos = <(String, DateTime?)>[
      ('Registro', _d(entrada.inicioRegistro)),
      ('Cierre', _d(entrada.cierreRegistro)),
      ('Proceso ACH', _d(entrada.retencionAch)),
      ('Pago', entrada.fechaPagoDate),
    ];
    int actual = pasos.indexWhere((s) => s.$2 != null && hoy.isBefore(s.$2!));
    if (actual < 0) actual = pasos.length - 1;
    return Container(
      decoration: _cardDeco(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PROCESO DEL PAGO', style: TextStyle(fontSize: 10.5, letterSpacing: 1.4, color: _mute, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < pasos.length; i++) ...[
              _Paso(
                label: pasos[i].$1,
                fecha: pasos[i].$2 == null ? '' : DateFormat('d MMM', 'es').format(pasos[i].$2!),
                done: i < actual,
                now: i == actual,
              ),
              if (i < pasos.length - 1)
                Expanded(child: Container(height: 2, margin: const EdgeInsets.only(top: 10), color: i < actual ? _acc : const Color(0x18FFFFFF))),
            ],
          ],
        ),
      ]),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.label, required this.fecha, required this.done, required this.now});
  final String label;
  final String fecha;
  final bool done;
  final bool now;
  @override
  Widget build(BuildContext context) {
    final Color dotBg = done ? _acc : (now ? const Color(0xFF0E1929) : _surf2);
    return SizedBox(
      width: 62,
      child: Column(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotBg,
            border: Border.all(color: done ? Colors.transparent : (now ? _acc : const Color(0x24FFFFFF)), width: 2),
            boxShadow: (done || now) ? const [BoxShadow(color: Color(0x8025E6A4), blurRadius: 12, spreadRadius: -3)] : null,
          ),
          child: done ? const Icon(Icons.check, size: 13, color: Color(0xFF0A150F)) : (now ? const Center(child: _Dot()) : null),
        ),
        const SizedBox(height: 7),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, height: 1.2, color: now ? _hi : _mid, fontWeight: now ? FontWeight.w700 : FontWeight.w500)),
        Text(fecha, style: const TextStyle(fontSize: 10.5, color: _mute)),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: _acc));
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});
  final EstadoFecha estado;
  @override
  Widget build(BuildContext context) {
    final (icon, label, c1, c2) = switch (estado) {
      EstadoFecha.publicada => (Icons.check_circle, 'Publicada', const Color(0xFF3BF0B4), _acc2),
      EstadoFecha.modificada => (Icons.edit, 'Modificada', _gold, const Color(0xFFCF9B2E)),
      EstadoFecha.pendiente => (Icons.schedule, 'Pendiente', const Color(0xFFB6C2D0), _mute),
      EstadoFecha.desactualizada => (Icons.warning_amber_rounded, 'Desactualizada', const Color(0xFFFF8E80), _danger),
      EstadoFecha.estimada => (Icons.timelapse, 'Estimada', const Color(0xFF9BB4E8), const Color(0xFF5C79C4)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [c1, c2]),
        boxShadow: [BoxShadow(color: c2.withValues(alpha: .5), blurRadius: 14, spreadRadius: -5)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: const Color(0xFF07130C)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF07130C))),
      ]),
    );
  }
}

// ───────────────────────── Calendario tab ─────────────────────────

class CalendarioTab extends StatelessWidget {
  const CalendarioTab({required this.ds, required this.seleccion, super.key});
  final Dataset ds;
  final Seleccion seleccion;
  @override
  Widget build(BuildContext context) {
    final hoy = hoyPanama();
    final fechas = ds.calendario.where((e) => e.categoria == seleccion.categoria).toList()
      ..sort((a, b) => a.fechaPagoDate.compareTo(b.fechaPagoDate));
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        Text('Calendario ${ds.manifest.semestres.isNotEmpty ? "2026" : ""}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _hi)),
        Text(seleccion is SeleccionEntidad ? '${seleccion.etiqueta} · ${seleccion.categoria.display}' : seleccion.etiqueta,
            style: const TextStyle(fontSize: 13, color: _mid)),
        const SizedBox(height: 14),
        for (final e in fechas)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: _cardDeco(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _surf2, border: Border.all(color: _line)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${e.fechaPagoDate.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _hi, height: 1)),
                  Text(DateFormat('MMM', 'es').format(e.fechaPagoDate), style: const TextStyle(fontSize: 10, color: _mid)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(DateFormat("EEEE d 'de' MMMM", 'es').format(e.fechaPagoDate),
                    style: TextStyle(fontSize: 14.5, color: e.fechaPagoDate.isBefore(hoy) ? _mute : _hi, fontWeight: FontWeight.w600)),
              ),
              Text('Q${e.quincena}', style: const TextStyle(fontSize: 12, color: _mid)),
            ]),
          ),
      ],
    );
  }
}

// ───────────────────────── Décimo tab ─────────────────────────

class DecimoTab extends StatelessWidget {
  const DecimoTab({required this.ds, super.key});
  final Dataset ds;
  @override
  Widget build(BuildContext context) {
    final hoy = hoyPanama();
    final idxProx = ds.xiii.indexWhere((x) => !x.fechaDate.isBefore(hoy));
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        const Text('Décimo Tercer Mes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _hi)),
        const Text('Las 3 fechas del XIII según el calendario del MEF.', style: TextStyle(fontSize: 13, color: _mid)),
        const SizedBox(height: 14),
        for (var i = 0; i < ds.xiii.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: i == idxProx ? _cardDeco(borde: const Color(0x3325E6A4), glow: true) : _cardDeco(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(children: [
              Icon(Icons.card_giftcard_rounded, color: ds.xiii[i].fechaDate.isBefore(hoy) ? _mute : _acc, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(DateFormat("d 'de' MMMM 'de' y", 'es').format(ds.xiii[i].fechaDate),
                    style: TextStyle(fontSize: 15.5, color: ds.xiii[i].fechaDate.isBefore(hoy) ? _mute : _hi, fontWeight: i == idxProx ? FontWeight.w700 : FontWeight.w500)),
              ),
              if (i == idxProx)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0x1F25E6A4), borderRadius: BorderRadius.circular(999)),
                  child: const Text('Próximo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _acc)),
                ),
            ]),
          ),
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
        const SizedBox(height: 6),
        const Text('Fechas del décimo según el calendario del MEF · App no oficial', style: TextStyle(fontSize: 11.5, color: _mute)),
      ],
    );
  }
}

// ───────────────────────── Onboarding ─────────────────────────

class OnboardingView extends StatefulWidget {
  const OnboardingView({required this.ops, required this.onConsultar, super.key});
  final List<Seleccion> ops;
  final ValueChanged<Seleccion> onConsultar;
  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final res = _filtrar(_q, widget.ops);
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        const Text('¿En qué institución trabajas?', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: _hi, height: 1.15)),
        const SizedBox(height: 6),
        const Text('Escribe el nombre o la sigla (ej. MIDES, MEDUCA) y ve cuándo pagan. El calendario cubre el Gobierno Central.', style: TextStyle(fontSize: 13.5, color: _mid, height: 1.45)),
        const SizedBox(height: 16),
        TextField(
          autofocus: true,
          style: const TextStyle(color: _hi),
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Buscar tu institución…',
            hintStyle: const TextStyle(color: _mute),
            prefixIcon: const Icon(Icons.search, color: _acc),
            filled: true,
            fillColor: _surf,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _acc, width: 1.6)),
          ),
        ),
        const SizedBox(height: 16),
        if (_q.trim().isNotEmpty && res.isEmpty) const _NoCubierta() else ...res.map((s) => _ItemInstitucion(sel: s, onTap: () => widget.onConsultar(s))),
      ],
    );
  }
}

class _ItemInstitucion extends StatelessWidget {
  const _ItemInstitucion({required this.sel, required this.onTap});
  final Seleccion sel;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: _cardDeco(),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(sel.etiqueta, style: const TextStyle(fontSize: 15.5, color: _hi, fontWeight: FontWeight.w500)),
                Text(_descSeleccion(sel), style: const TextStyle(fontSize: 12.5, color: _mute)),
              ]),
            ),
            const Icon(Icons.chevron_right, color: _mute),
          ]),
        ),
      ),
    );
  }
}

class _NoCubierta extends StatelessWidget {
  const _NoCubierta();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0x14F4C868), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0x33F4C868))),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.help_outline, size: 18, color: _gold), SizedBox(width: 8), Expanded(child: Text('No la encontramos en el calendario del MEF', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _gold)))]),
        SizedBox(height: 8),
        Text('El calendario publicado cubre las entidades del Gobierno Central. No incluye municipios ni algunas entidades descentralizadas. Revisa el nombre o la sigla.', style: TextStyle(fontSize: 13, color: Color(0xFFD9C79A), height: 1.45)),
      ]),
    );
  }
}

// ───────────────────────── Disclaimer ─────────────────────────

class DisclaimerGate extends StatelessWidget {
  const DisclaimerGate({required this.onContinuar, super.key});
  final VoidCallback onContinuar;
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(18, 24, 18, 24), children: [
      Container(
        decoration: _cardDeco(glow: true),
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 46, height: 46, decoration: const BoxDecoration(color: Color(0x1AF4C868), shape: BoxShape.circle), child: const Icon(Icons.info_outline, color: _gold, size: 24)),
          const SizedBox(height: 16),
          const Text('App independiente y no oficial', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _hi, height: 1.2)),
          const SizedBox(height: 10),
          const Text('No representa al Gobierno de Panamá ni al MEF. Muestra fechas que el MEF publica en sus canales oficiales, para consultarlas más fácil. Las fechas son referenciales; no tramitamos ni resolvemos pagos.', style: TextStyle(fontSize: 14.5, color: _mid, height: 1.5)),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _acc, foregroundColor: const Color(0xFF07130C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: onContinuar,
              child: const Text('Continuar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          // Aceptación implícita (patrón tipo Google): al continuar, se reconoce el carácter no oficial.
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('Al continuar aceptas que es una app independiente y no oficial. ', style: TextStyle(fontSize: 12, color: _mute, height: 1.4)),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacidadScreen())),
              child: const Text('Ver privacidad ›', style: TextStyle(fontSize: 12, color: _acc, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    ]);
  }
}

// ───────────────────────── Acerca de / Privacidad ─────────────────────────

Widget _seccion(String t, String c) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _hi)),
        const SizedBox(height: 6),
        Text(c, style: const TextStyle(fontSize: 14, color: _mid, height: 1.5)),
      ]),
    );

Widget _enlace(BuildContext context, IconData icon, String texto, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _cardDeco(),
          child: Row(children: [
            Icon(icon, size: 18, color: _acc),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 14.5, color: _hi))),
            const Icon(Icons.chevron_right, color: _mute),
          ]),
        ),
      ),
    );

class AcercaContenido extends StatelessWidget {
  const AcercaContenido({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 24), children: _acercaHijos(context));
}

class AcercaDeScreen extends StatelessWidget {
  const AcercaDeScreen({super.key});
  @override
  Widget build(BuildContext context) => _legalScaffold(context, 'Acerca de', _acercaHijos(context));
}

List<Widget> _acercaHijos(BuildContext context) => [
      const Text('App independiente y no oficial', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _hi, height: 1.15)),
      const SizedBox(height: 14),
      _seccion('Qué es', '«¿Cuándo Pagan?» es un proyecto independiente, gratuito y de código abierto que te muestra las fechas de pago del sector público de Panamá: jubilados, gastos de representación y grupos 1, 2 y 3.'),
      _seccion('Qué NO es', 'No es una app oficial del Gobierno de Panamá. No está afiliada, patrocinada ni avalada por el MEF ni por ninguna entidad del Estado. No tramita ni resuelve pagos.'),
      _seccion('De dónde salen las fechas', 'Se transcriben de lo que el MEF publica en sus canales oficiales. Las fechas son referenciales; ante cualquier diferencia, prevalece la publicación oficial del MEF.'),
      _seccion('Privacidad', 'No pedimos cuenta ni datos personales. En la web usamos analítica agregada y sin cookies (Cloudflare); la app móvil, no. Lo tuyo se queda en tu dispositivo.'),
      _seccion('Código abierto', 'El código y los datos son públicos y auditables.'),
      const SizedBox(height: 4),
      _enlace(context, Icons.open_in_new, 'Ver el calendario en el sitio del MEF', () => _abrir(_mefFullUrl)),
      _enlace(context, Icons.code, 'Código fuente (repositorio)', () => _abrir('https://$_repoUrl')),
      _enlace(context, Icons.mail_outline, 'Escríbenos: $_contacto', () => _abrir('mailto:$_contacto')),
      _enlace(context, Icons.language, 'Hecho por 3qbic', () => _abrir(_sitio3qbic)),
      _enlace(context, Icons.workspace_premium_outlined, 'Licencias de software (open source)', () => showLicensePage(context: context, applicationName: '¿Cuándo Pagan?', applicationVersion: '0.3.0', applicationLegalese: '© 2026 $_titular — Alexis García')),
      _enlace(context, Icons.privacy_tip_outlined, 'Política de privacidad', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacidadScreen()))),
      const SizedBox(height: 12),
      const Text('© 2026 3qbic · ¿Cuándo Pagan? · Hecho por Alexis García · Licencia MIT.', style: TextStyle(fontSize: 12, color: _mute, height: 1.4)),
    ];

class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});
  @override
  Widget build(BuildContext context) => _legalScaffold(context, 'Política de privacidad', [
        const Text('Política de privacidad', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _hi)),
        const Text('Resumen: no recolectamos datos personales. Lo tuyo se queda en tu teléfono.', style: TextStyle(fontSize: 14, color: _mid)),
        const SizedBox(height: 16),
        _seccion('1. Quiénes somos', 'App independiente, gratuita y de código abierto. No es oficial del Gobierno ni del MEF. Responsable: 3qbic (3qbic.com).'),
        _seccion('2. No recolectamos datos personales', 'Funciona en tu dispositivo. Sin cuenta. No pedimos nombre, cédula, teléfono ni correo. No usamos publicidad, rastreadores publicitarios ni perfiles de usuario.'),
        _seccion('3. Qué se guarda en tu dispositivo', 'Tu institución favorita, preferencias y una copia del calendario. Nunca sale de tu dispositivo.'),
        _seccion('4. Conexión a internet', 'Descarga el calendario (datos públicos) desde infraestructura de 3qbic sobre Cloudflare. No se envían datos personales; Cloudflare procesa tu IP de forma técnica y temporal solo para entregar el contenido.'),
        _seccion('5. Analítica (solo versión web)', 'La versión web (cuandopagan.3qbic.com) usa analítica agregada y sin cookies (Cloudflare Web Analytics): cuenta visitas y velocidad de carga de forma anónima, sin cookies, sin identificarte y sin seguirte entre sitios. La app móvil no incluye ninguna analítica.'),
        _seccion('6. Tus derechos (Ley 81/2019)', 'Derechos ARCO. Como no almacenamos datos personales en servidores, tú controlas tu información en el dispositivo. Autoridad: ANTAI.'),
        _seccion('7. Contacto', '$_contacto · $_repoUrl'),
      ]);
}

Scaffold _legalScaffold(BuildContext context, String titulo, List<Widget> hijos) => Scaffold(
      backgroundColor: _bg0,
      appBar: AppBar(backgroundColor: _bg1, surfaceTintColor: Colors.transparent, elevation: 0, foregroundColor: _hi, title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
      body: _Fondo(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: hijos),
            ),
          ),
        ),
      ),
    );
