import '../entities/entrada_calendario.dart';
import '../entities/manifest.dart';

List<Cambio> detectarModificadas({
  required List<EntradaCalendario> previas,
  required List<EntradaCalendario> nuevas,
  required int desdeVersion,
}) {
  final mapPrev = {for (final e in previas) e.slotKey: e.fechaPago};
  final cambios = <Cambio>[];
  for (final n in nuevas) {
    final antes = mapPrev[n.slotKey];
    if (antes != null && antes != n.fechaPago) {
      cambios.add(Cambio(
        clave: n.slotKey, fechaAnterior: antes,
        fechaNueva: n.fechaPago, desdeVersion: desdeVersion));
    }
  }
  return cambios;
}
