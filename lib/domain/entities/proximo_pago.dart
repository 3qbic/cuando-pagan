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
