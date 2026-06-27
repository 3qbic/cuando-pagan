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

DateTime _defaultAhora() => DateTime.now().toUtc();

class CalendarioRepositoryImpl implements CalendarioRepository {
  CalendarioRepositoryImpl({
    required this.db, required this.api, required this.seed,
    DateTime Function()? ahora,
  }) : _ahora = ahora ?? _defaultAhora;

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
