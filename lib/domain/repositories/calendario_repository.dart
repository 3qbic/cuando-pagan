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
