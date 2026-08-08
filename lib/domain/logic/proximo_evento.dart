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
