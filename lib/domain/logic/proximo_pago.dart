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
