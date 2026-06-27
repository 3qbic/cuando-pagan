import '../entities/entidad.dart';
import '../../core/text/normalizar.dart';

List<Entidad> buscarEntidades(String query, List<Entidad> universo) {
  final q = normalizar(query);
  final ordenado = [...universo]..sort((a, b) => a.display.compareTo(b.display));
  if (q.isEmpty) return ordenado;
  return ordenado.where((e) {
    final porSigla = e.siglas.any((s) => normalizar(s).contains(q));
    final porNombre =
        normalizar(e.display).contains(q) || normalizar(e.nombreWire).contains(q);
    return porSigla || porNombre;
  }).toList();
}
