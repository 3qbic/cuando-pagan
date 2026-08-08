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
