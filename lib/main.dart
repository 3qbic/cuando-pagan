import 'dart:convert';
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
import 'data/mappers.dart';
import 'domain/entities/categoria.dart';
import 'domain/entities/entidad.dart';
import 'domain/entities/entrada_calendario.dart';
import 'domain/entities/estado_fecha.dart';
import 'domain/entities/manifest.dart';
import 'domain/entities/proximo_pago.dart';
import 'domain/entities/seleccion.dart';
import 'domain/entities/xiii_mes.dart';
import 'domain/logic/contador.dart';
import 'domain/logic/proximo_pago.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initZonaPanama();
  await initializeDateFormatting('es');
  runApp(const CuandoPaganApp());
}

// ── Tokens (dirección clara / confiable, acento teal). Final = Claude Design. ──
const _accent = Color(0xFF0E7C66);
const _accentSoft = Color(0xFFE7F4EE);
const _heroTint = Color(0xFFF0FAF5);
const _ink = Color(0xFF14211D);
const _muted = Color(0xFF6A746F);
const _bg = Color(0xFFF4F6F5);
const _line = Color(0xFFE4E9E7);
const _amber = Color(0xFF9A6400);
const _amberBg = Color(0xFFFFF8EE);
const _amberLine = Color(0xFFF0DCBC);

const _r = 18.0; // radio de tarjeta consistente (Similarity / Prägnanz)
const _kFavorita = 'favorita';
const _kDisclaimer = 'disclaimerAck';

// Marca / operador: 3qbic. Repo/correo: confirmar antes de publicar.
const _titular = '3qbic';
const _sitio3qbic = 'https://3qbic.com';
const _repoUrl = 'github.com/3qbic/cuando-pagan';
const _contacto = 'cuandopagan@3qbic.com';
const _mefUrl = 'www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico';
const _mefFullUrl = 'https://www.mef.gob.pa/transparencia/calendario-de-pago-del-sector-publico/';

Future<void> _abrir(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
}

BoxDecoration _card({Color bg = Colors.white, Color? border, bool sombra = false}) => BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(_r),
      border: Border.all(color: border ?? _line),
      boxShadow: sombra ? const [BoxShadow(color: Color(0x0F0E7C66), blurRadius: 22, offset: Offset(0, 8))] : null,
    );

class CuandoPaganApp extends StatelessWidget {
  const CuandoPaganApp({super.key});
  @override
  Widget build(BuildContext context) {
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: _accent, brightness: Brightness.light),
        scaffoldBackgroundColor: _bg,
      ),
      home: const RootPage(),
    );
  }
}

// ───────────────────────── Datos ─────────────────────────

class Dataset {
  final Manifest manifest;
  final List<EntradaCalendario> calendario;
  final List<Entidad> entidades;
  final List<XiiiMes> xiii;
  Dataset(this.manifest, this.calendario, this.entidades, this.xiii);
}

Future<Dataset> _cargar() async {
  final all = jsonDecode(await rootBundle.loadString('assets/seed/all.json')) as Map<String, dynamic>;
  final siglas = cargarSiglas(
      jsonDecode(await rootBundle.loadString('assets/data/siglas_entidades.json')) as Map<String, dynamic>);
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
      return normalizar(e.display).contains(n) ||
          normalizar(e.nombreWire).contains(n) ||
          e.siglas.any((x) => normalizar(x).contains(n));
    }
    return normalizar(s.etiqueta).contains(n);
  }).toList();
}

/// Pago cuya fecha ya pasó pero dentro de una ventana corta (≤6 días): "ya debió pagarse".
(EntradaCalendario, int)? _pagoReciente(List<EntradaCalendario> entradas) {
  final hoy = hoyPanama();
  final pasadas = entradas.where((e) => e.fechaPagoDate.isBefore(hoy)).toList()
    ..sort((a, b) => b.fechaPagoDate.compareTo(a.fechaPagoDate));
  if (pasadas.isEmpty) return null;
  final r = pasadas.first;
  final dias = hoy.difference(r.fechaPagoDate).inDays;
  return dias <= 6 ? (r, dias) : null;
}

// ───────────────────────── Shell ─────────────────────────

class RootPage extends StatefulWidget {
  const RootPage({super.key});
  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  Dataset? _ds;
  List<Seleccion> _ops = const [];
  Seleccion? _sel;
  bool _cargando = true;
  bool _disclaimerAck = false;

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
    if (!mounted) return;
    setState(() {
      _ds = ds;
      _ops = _opciones(ds);
      _sel = token == null ? null : Seleccion.fromToken(token, ds.entidades);
      _disclaimerAck = ack;
      _cargando = false;
    });
  }

  Future<void> _aceptarDisclaimer() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDisclaimer, true);
    if (mounted) setState(() => _disclaimerAck = true);
  }

  Future<void> _guardar(Seleccion s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFavorita, s.toToken());
    if (mounted) setState(() => _sel = s);
  }

  Future<void> _cambiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFavorita);
    if (mounted) setState(() => _sel = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                Expanded(
                  child: _cargando
                      ? const Center(child: CircularProgressIndicator())
                      : !_disclaimerAck
                          ? DisclaimerGate(onEntendido: _aceptarDisclaimer)
                          : _sel == null
                              ? OnboardingView(ops: _ops, onGuardar: _guardar)
                              : HomeView(ds: _ds!, seleccion: _sel!, onCambiar: _cambiar),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 6, 4),
      child: Row(children: [
        const Text('¿Cuándo Pagan?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.3)),
        const Spacer(),
        Semantics(
          button: true,
          label: 'Aviso: aplicación independiente, no oficial, no afiliada al Gobierno de Panamá. Toca para Acerca de.',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AcercaDeScreen())),
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _amberBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _amberLine),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.info_outline, size: 13, color: _amber),
                SizedBox(width: 5),
                Text('No oficial', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _amber)),
              ]),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: _ink, size: 22),
          tooltip: 'Más',
          onSelected: (v) => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => v == 'acerca' ? const AcercaDeScreen() : const PrivacidadScreen())),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'acerca', child: Text('Acerca de')),
            PopupMenuItem(value: 'privacidad', child: Text('Política de privacidad')),
          ],
        ),
      ]),
    );
  }
}

// Disclaimer-first bloqueante (Definition of Done) — primer uso.
class DisclaimerGate extends StatelessWidget {
  const DisclaimerGate({required this.onEntendido, super.key});
  final VoidCallback onEntendido;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _card(sombra: true),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: _amberBg, shape: BoxShape.circle, border: Border.all(color: _amberLine)),
              child: const Icon(Icons.info_outline, color: _amber, size: 24),
            ),
            const SizedBox(height: 16),
            const Text('App independiente y no oficial',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: _ink, height: 1.2)),
            const SizedBox(height: 10),
            const Text(
              'No representa al Gobierno de Panamá ni al MEF. Muestra fechas que el MEF publica en sus '
              'canales oficiales, para consultarlas más fácil. Las fechas son referenciales; no tramitamos '
              'ni resolvemos pagos.',
              style: TextStyle(fontSize: 14.5, color: Color(0xFF3F4A46), height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: onEntendido,
                child: const Text('Entendido', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacidadScreen())),
                child: const Text('Ver política de privacidad'),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// ───────────────────────── Onboarding ─────────────────────────

class OnboardingView extends StatefulWidget {
  const OnboardingView({required this.ops, required this.onGuardar, super.key});
  final List<Seleccion> ops;
  final ValueChanged<Seleccion> onGuardar;
  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  String _q = '';
  Seleccion? _cand;

  @override
  Widget build(BuildContext context) {
    if (_cand != null) return _confirmacion(context, _cand!);
    final res = _filtrar(_q, widget.ops);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      children: [
        const Text('¿En qué institución trabajas?',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: _ink, height: 1.15)),
        const SizedBox(height: 6),
        const Text('Escribe el nombre o la sigla (ej. MIDES, MEDUCA). El calendario cubre el Gobierno Central.',
            style: TextStyle(fontSize: 13.5, color: _muted, height: 1.45)),
        const SizedBox(height: 18),
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Buscar tu institución…',
            prefixIcon: const Icon(Icons.search, color: _accent),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _accent, width: 1.6)),
          ),
        ),
        const SizedBox(height: 16),
        if (_q.trim().isNotEmpty && res.isEmpty)
          const _NoCubierta()
        else
          ...res.map((s) => _ItemInstitucion(sel: s, onTap: () => setState(() => _cand = s))),
      ],
    );
  }

  Widget _confirmacion(BuildContext context, Seleccion s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: _card(sombra: true),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: _accent, size: 26),
            ),
            const SizedBox(height: 16),
            const Text('¡Todo en orden!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 4),
            const Text('Tu institución está en el calendario del MEF.',
                style: TextStyle(fontSize: 14, color: _muted)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.etiqueta, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 2),
                Text(s.categoria.display, style: const TextStyle(fontSize: 13, color: _muted)),
              ]),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () => widget.onGuardar(s),
                icon: const Icon(Icons.bookmark_added_outlined, size: 19),
                label: const Text('Guardar y ver mis pagos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 6),
            Center(child: TextButton(onPressed: () => setState(() => _cand = null), child: const Text('Elegir otra'))),
            const SizedBox(height: 2),
            const Text('La guardamos solo en tu teléfono. Puedes cambiarla cuando quieras.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF9AA39F), height: 1.4)),
          ]),
        ),
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
    final sigla = sel is SeleccionEntidad && (sel as SeleccionEntidad).entidad.siglas.isNotEmpty
        ? (sel as SeleccionEntidad).entidad.siglas.first
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(sel.etiqueta, style: const TextStyle(fontSize: 15.5, color: _ink, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${sel.categoria.display}${sigla != null ? ' · $sigla' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: _muted)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB8C0BC)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NoCubierta extends StatelessWidget {
  const _NoCubierta();
  @override
  Widget build(BuildContext context) {
    return _AvisoAmber(
      titulo: 'No la encontramos en el calendario del MEF',
      cuerpo: 'El calendario publicado cubre las entidades del Gobierno Central. No incluye municipios '
          'ni algunas entidades descentralizadas. Revisa el nombre o la sigla; si tu institución no '
          'aparece, su pago no sale en esta fuente.',
      icono: Icons.help_outline,
    );
  }
}

// ───────────────────────── Home ─────────────────────────

class HomeView extends StatefulWidget {
  const HomeView({required this.ds, required this.seleccion, required this.onCambiar, super.key});
  final Dataset ds;
  final Seleccion seleccion;
  final VoidCallback onCambiar;
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  bool _verXiii = false;

  @override
  Widget build(BuildContext context) {
    final ds = widget.ds;
    final entradas = ds.calendario.where((e) => e.categoria == widget.seleccion.categoria).toList();
    final pago = calcularProximoPago(
      entradasDeCategoria: entradas,
      seleccion: widget.seleccion,
      manifest: ds.manifest,
      remoteDataVersion: ds.manifest.dataVersion,
    );
    final reciente = _pagoReciente(entradas);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
      children: [
        _BarraInstitucion(seleccion: widget.seleccion, onCambiar: widget.onCambiar),
        const SizedBox(height: 12),
        if (reciente != null) ...[
          _AvisoPagoReciente(entrada: reciente.$1, diasAtras: reciente.$2),
          const SizedBox(height: 12),
        ],
        _Hero(pago: pago),
        const SizedBox(height: 12),
        _BotonXiii(abierto: _verXiii, onTap: () => setState(() => _verXiii = !_verXiii)),
        if (_verXiii) ...[
          const SizedBox(height: 10),
          _CardXiii(xiii: ds.xiii),
        ],
        const SizedBox(height: 18),
        _PieLegal(manifest: ds.manifest),
      ],
    );
  }
}

class _BarraInstitucion extends StatelessWidget {
  const _BarraInstitucion({required this.seleccion, required this.onCambiar});
  final Seleccion seleccion;
  final VoidCallback onCambiar;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _card(),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MI INSTITUCIÓN',
                style: TextStyle(fontSize: 10.5, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: _muted)),
            const SizedBox(height: 3),
            Text(seleccion.etiqueta,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: _ink), maxLines: 2),
            Text(seleccion.categoria.display, style: const TextStyle(fontSize: 12.5, color: _muted)),
          ]),
        ),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onCambiar,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_horiz, size: 18, color: _accent),
              SizedBox(width: 4),
              Text('Cambiar', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _accent)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.pago});
  final ProximoPago pago;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _card(bg: _heroTint, border: const Color(0x330E7C66), sombra: true),
      child: pago.hayFecha ? _conFecha() : _pendiente(),
    );
  }

  Widget _conFecha() {
    final f = pago.entrada!.fechaPagoDate;
    final mes = DateFormat('MMMM', 'es').format(f);
    final diaSemana = DateFormat('EEEE', 'es').format(f);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('PRÓXIMO PAGO',
          style: TextStyle(fontSize: 11.5, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: _accent)),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text('${f.day}', style: const TextStyle(fontSize: 76, height: 0.9, fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('de $mes', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _ink)),
          Text(diaSemana, style: const TextStyle(fontSize: 15, color: _muted)),
        ]),
      ]),
      const SizedBox(height: 16),
      _Contador(dias: pago.diasRestantes),
      const SizedBox(height: 18),
      Row(children: [
        _EstadoChip(estado: pago.estado),
        const Spacer(),
        InkWell(
          onTap: () => _abrir(_mefFullUrl),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Fuente pública: MEF', style: TextStyle(fontSize: 12.5, color: _accent, fontWeight: FontWeight.w600)),
              SizedBox(width: 3),
              Icon(Icons.open_in_new, size: 13, color: _accent),
            ]),
          ),
        ),
      ]),
    ]);
  }

  Widget _pendiente() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('PRÓXIMO PAGO',
          style: TextStyle(fontSize: 11.5, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: _accent)),
      const SizedBox(height: 14),
      _EstadoChip(estado: pago.estado),
      const SizedBox(height: 12),
      const Text('El MEF aún no publica este período.', style: TextStyle(fontSize: 17, color: _ink, height: 1.4)),
      const SizedBox(height: 10),
      const Text('Fuente pública: MEF · App no oficial', style: TextStyle(fontSize: 12.5, color: _muted)),
    ]);
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.dias});
  final int dias;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.schedule, size: 17, color: _accent),
        const SizedBox(width: 7),
        Text(etiquetaContador(dias),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _accent)),
      ]),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});
  final EstadoFecha estado;
  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (estado) {
      EstadoFecha.publicada => (Icons.check_circle_outline, 'Publicada', const Color(0xFF1E7A4D)),
      EstadoFecha.modificada => (Icons.edit_outlined, 'Modificada', const Color(0xFF9A6400)),
      EstadoFecha.pendiente => (Icons.schedule_outlined, 'Pendiente', _muted),
      EstadoFecha.desactualizada => (Icons.warning_amber_outlined, 'Desactualizada', const Color(0xFFC13D26)),
      EstadoFecha.estimada => (Icons.timelapse_outlined, 'Estimada', const Color(0xFF3F5688)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: color)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// Aviso contextual (barra de acento a la izquierda) — no "banner".
class _AvisoPagoReciente extends StatelessWidget {
  const _AvisoPagoReciente({required this.entrada, required this.diasAtras});
  final EntradaCalendario entrada;
  final int diasAtras;
  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat("d 'de' MMMM", 'es').format(entrada.fechaPagoDate);
    final cuando = diasAtras == 0 ? 'hoy' : (diasAtras == 1 ? 'ayer' : 'hace $diasAtras días');
    return _AvisoAmber(
      titulo: 'Tu pago estaba programado para el $fecha ($cuando)',
      cuerpo: 'Según el calendario del MEF debió realizarse en esa fecha. Las fechas son referenciales: '
          'si aún no lo recibes, el depósito puede tardar o variar — verifica con tu institución o en el sitio del MEF.',
      icono: Icons.history,
    );
  }
}

class _AvisoAmber extends StatelessWidget {
  const _AvisoAmber({required this.titulo, required this.cuerpo, required this.icono});
  final String titulo;
  final String cuerpo;
  final IconData icono;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 4, color: _amber),
          Expanded(
            child: Container(
              color: _amberBg,
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icono, size: 18, color: _amber),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(titulo,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _amber, height: 1.3))),
                ]),
                const SizedBox(height: 7),
                Text(cuerpo, style: const TextStyle(fontSize: 12.8, color: Color(0xFF7A5A2A), height: 1.45)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BotonXiii extends StatelessWidget {
  const _BotonXiii({required this.abierto, required this.onTap});
  final bool abierto;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_r),
      child: InkWell(
        borderRadius: BorderRadius.circular(_r),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: _card(),
          child: Row(children: [
            const Icon(Icons.card_giftcard_outlined, color: _accent, size: 20),
            const SizedBox(width: 10),
            const Expanded(
                child: Text('¿Cuándo pagan el décimo (XIII)?',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _ink))),
            Icon(abierto ? Icons.expand_less : Icons.expand_more, color: _muted),
          ]),
        ),
      ),
    );
  }
}

class _CardXiii extends StatelessWidget {
  const _CardXiii({required this.xiii});
  final List<XiiiMes> xiii;
  @override
  Widget build(BuildContext context) {
    final hoy = hoyPanama();
    final idxProximo = xiii.indexWhere((x) => !x.fechaDate.isBefore(hoy));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DÉCIMO TERCER MES (XIII)',
            style: TextStyle(fontSize: 10.5, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: _accent)),
        const SizedBox(height: 12),
        for (var i = 0; i < xiii.length; i++) _fila(xiii[i], esProximo: i == idxProximo, pasado: xiii[i].fechaDate.isBefore(hoy)),
        const SizedBox(height: 4),
        const Text('Fechas del décimo según el calendario del MEF · App no oficial',
            style: TextStyle(fontSize: 11.5, color: _muted)),
      ]),
    );
  }

  Widget _fila(XiiiMes x, {required bool esProximo, required bool pasado}) {
    final f = DateFormat("d 'de' MMMM 'de' y", 'es').format(x.fechaDate);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(Icons.event, size: 18, color: pasado ? const Color(0xFFB8C0BC) : _accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(f,
              style: TextStyle(
                  fontSize: 15,
                  color: pasado ? _muted : _ink,
                  fontWeight: esProximo ? FontWeight.w700 : FontWeight.w400)),
        ),
        if (esProximo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(999)),
            child: const Text('Próximo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _accent)),
          ),
      ]),
    );
  }
}

class _PieLegal extends StatelessWidget {
  const _PieLegal({required this.manifest});
  final Manifest manifest;
  void _ir(BuildContext c, Widget s) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => s));
  @override
  Widget build(BuildContext context) {
    const muteStyle = TextStyle(fontSize: 11.5, color: Color(0xFF9AA39F), height: 1.45);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        'Datos del ${manifest.fechaPublicacion} · ${manifest.totalFilas} fechas. '
        'Fuente pública: MEF · App no afiliada. La información oficial y vinculante es la del MEF.',
        style: muteStyle,
      ),
      const SizedBox(height: 10),
      const Divider(height: 1, color: _line),
      const SizedBox(height: 10),
      const Text('© 2026 3qbic · ¿Cuándo Pagan? · Proyecto independiente y de código abierto.', style: muteStyle),
      const SizedBox(height: 6),
      Row(children: [
        TextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 40)),
          onPressed: () => _ir(context, const AcercaDeScreen()),
          child: const Text('Acerca de', style: TextStyle(fontSize: 12.5, color: _accent)),
        ),
        const Text('·', style: muteStyle),
        TextButton(
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 40)),
          onPressed: () => _ir(context, const PrivacidadScreen()),
          child: const Text('Política de privacidad', style: TextStyle(fontSize: 12.5, color: _accent)),
        ),
      ]),
    ]);
  }
}

// Sección de texto reutilizable para pantallas legales.
Widget _seccion(String titulo, String cuerpo) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 6),
        Text(cuerpo, style: const TextStyle(fontSize: 14, color: Color(0xFF3F4A46), height: 1.5)),
      ]),
    );

Widget _enlace(BuildContext context, IconData icon, String texto, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
            child: Row(children: [
              Icon(icon, size: 18, color: _accent),
              const SizedBox(width: 12),
              Expanded(child: Text(texto, style: const TextStyle(fontSize: 14.5, color: _ink))),
              const Icon(Icons.chevron_right, color: Color(0xFFB8C0BC)),
            ]),
          ),
        ),
      ),
    );

Scaffold _pantallaLegal(BuildContext context, String titulo, List<Widget> hijos) => Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: hijos),
          ),
        ),
      ),
    );

class AcercaDeScreen extends StatelessWidget {
  const AcercaDeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _pantallaLegal(context, 'Acerca de', [
      const Text('App independiente y no oficial',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink, height: 1.15)),
      const SizedBox(height: 14),
      _seccion('Qué es',
          '«¿Cuándo Pagan?» es un proyecto independiente, gratuito y de código abierto que te muestra de '
          'forma rápida y clara las fechas de pago del sector público de Panamá: jubilados, gastos de '
          'representación y grupos 1, 2 y 3.'),
      _seccion('Qué NO es',
          'No es una app oficial del Gobierno de Panamá. No está afiliada, patrocinada ni avalada por el '
          'Ministerio de Economía y Finanzas (MEF) ni por ninguna entidad del Estado. No tramita ni '
          'resuelve pagos: para eso, contacta a tu entidad o al MEF.'),
      _seccion('De dónde salen las fechas',
          'Las fechas se transcriben de lo que el MEF publica en sus canales oficiales. Solo mostramos lo ya '
          'publicado; los períodos que el MEF aún no publica aparecen como “Pendiente”. Cada fecha muestra su '
          'estado (Publicada, Modificada o Desactualizada). Las fechas son referenciales; ante cualquier '
          'diferencia, prevalece la publicación oficial del MEF.\n\nVer la fuente: $_mefUrl'),
      _seccion('Privacidad',
          'No pedimos cuenta ni datos personales. No recolectamos ni compartimos información. Todo se queda '
          'en tu dispositivo. Lee la Política de privacidad desde el menú o el pie de la app.'),
      _seccion('Código abierto',
          'El código y los datos son públicos y auditables: puedes ver exactamente cómo funciona y de dónde '
          'sale cada fecha.\n\nRepositorio: $_repoUrl'),
      _seccion('Contacto',
          'Este NO es un canal oficial del Gobierno. Nunca te pediremos cédula, número de cuenta bancaria ni '
          'datos personales. Para reportar un error o sugerencia: $_contacto'),
      _seccion('Aviso final',
          'Recuerda: esta es una herramienta informativa independiente. La información oficial y vinculante '
          'siempre es la del Ministerio de Economía y Finanzas (MEF) de Panamá. Los días restantes se '
          'calculan en hora de Panamá; requiere que el reloj de tu dispositivo esté correcto.'),
      const SizedBox(height: 4),
      _enlace(context, Icons.open_in_new, 'Ver el calendario en el sitio del MEF', () => _abrir(_mefFullUrl)),
      _enlace(context, Icons.code, 'Código fuente (repositorio)', () => _abrir('https://$_repoUrl')),
      _enlace(context, Icons.mail_outline, 'Escríbenos: $_contacto', () => _abrir('mailto:$_contacto')),
      _enlace(context, Icons.language, 'Hecho por 3qbic', () => _abrir(_sitio3qbic)),
      _enlace(context, Icons.workspace_premium_outlined, 'Licencias de software (open source)',
          () => showLicensePage(
              context: context,
              applicationName: '¿Cuándo Pagan?',
              applicationVersion: '0.1.0',
              applicationLegalese: '© 2026 $_titular — Alexis García')),
      const SizedBox(height: 12),
      const Text('© 2026 3qbic · ¿Cuándo Pagan? · Hecho por Alexis García · Licencia MIT.',
          style: TextStyle(fontSize: 12, color: Color(0xFF9AA39F), height: 1.4)),
    ]);
  }
}

class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _pantallaLegal(context, 'Política de privacidad', [
      const Text('Política de privacidad',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _ink, height: 1.15)),
      const SizedBox(height: 4),
      const Text('Resumen: no recolectamos tus datos. Todo se queda en tu teléfono.',
          style: TextStyle(fontSize: 14, color: _muted)),
      const SizedBox(height: 16),
      _seccion('1. Quiénes somos',
          '«¿Cuándo Pagan?» es una aplicación independiente, gratuita y de código abierto. No es una app '
          'oficial del Gobierno de Panamá ni del MEF. El MEF se cita únicamente como fuente pública de la '
          'información. Responsable del proyecto: 3qbic (3qbic.com).'),
      _seccion('2. No recolectamos tus datos',
          'La app funciona 100% en tu dispositivo. No necesitas crear una cuenta. No pedimos tu nombre, '
          'cédula, teléfono ni correo. No tenemos servidores donde se guarde información tuya. No usamos '
          'publicidad, rastreadores ni perfiles de usuario.'),
      _seccion('3. Qué se guarda en tu dispositivo',
          'Para que la app sea útil sin conexión, guarda localmente: tu institución favorita, tus '
          'preferencias y una copia (caché) del calendario descargado. Esta información nunca sale de tu '
          'dispositivo y no está asociada a tu identidad. Puedes borrarla limpiando el almacenamiento o '
          'desinstalando.'),
      _seccion('4. Conexión a internet',
          'La app se conecta a nuestro servicio de distribución para descargar y actualizar el calendario '
          '(datos públicos). En esa conexión no se envía ningún dato personal tuyo. El proveedor de '
          'infraestructura (Cloudflare) procesa de forma técnica y temporal tu dirección IP solo para '
          'entregar el contenido; no la usamos para identificarte. No usamos cookies ni identificadores de '
          'seguimiento.'),
      _seccion('5. Permisos',
          'Acceso a internet: para descargar y actualizar el calendario. (Si en el futuro agregamos '
          'recordatorios, pediremos permiso de notificaciones solo si los activas.) No pedimos ubicación, '
          'contactos, cámara, micrófono ni tu identidad.'),
      _seccion('6. Terceros',
          'Cloudflare aloja y entrega el calendario (ver punto 4). Las tiendas (Google Play, App Store) '
          'recolectan sus propias estadísticas conforme a sus políticas, fuera de nuestro control. No '
          'compartimos ni vendemos datos personales, porque no los recolectamos.'),
      _seccion('7. Tus derechos (Ley 81 de 2019, Panamá)',
          'La Ley 81 reconoce derechos de acceso, rectificación, cancelación, oposición y portabilidad. Como '
          'no almacenamos datos personales en servidores, no existe una base de datos tuya que consultar o '
          'eliminar; tú controlas tu información en tu dispositivo. La autoridad competente es la ANTAI.'),
      _seccion('8. Seguridad y cambios',
          'La descarga del calendario usa conexión cifrada (HTTPS). Si cambiamos esta política, lo '
          'indicaremos aquí y cualquier recolección futura será informada y, cuando corresponda, opcional.'),
      _seccion('9. Contacto',
          '$_contacto · $_repoUrl'),
    ]);
  }
}
