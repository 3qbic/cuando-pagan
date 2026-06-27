import '../entities/xiii_mes.dart';
import '../../core/text/normalizar.dart';
import '../../core/time/hoy_panama.dart';

bool consultaEsSobreXiii(String query) {
  final q = normalizar(query);
  const claves = ['decimo tercer', 'decimotercer', 'treceavo', 'xiii', '13'];
  return claves.any(q.contains);
}

List<XiiiMes> proximasXiii(List<XiiiMes> todas, {DateTime? ahora}) {
  final hoy = hoyPanama(ahora: ahora);
  final orden = [...todas]..sort((a, b) => a.fechaDate.compareTo(b.fechaDate));
  final futuras = orden.where((x) => !x.fechaDate.isBefore(hoy)).toList();
  return futuras.isNotEmpty ? futuras : orden;
}
