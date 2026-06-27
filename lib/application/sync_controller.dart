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
