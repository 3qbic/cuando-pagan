import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/xiii_mes.dart';
import 'package:cuando_pagan/domain/logic/consulta_xiii.dart';

final xiii = const [
  XiiiMes(anio: 2026, semestre: 1, mes: 'FEBRERO', fechaAprox: '2026-02-20'),
  XiiiMes(anio: 2026, semestre: 2, mes: 'AGOSTO', fechaAprox: '2026-08-06'),
  XiiiMes(anio: 2026, semestre: 2, mes: 'DICIEMBRE', fechaAprox: '2026-12-04'),
];

void main() {
  setUpAll(initZonaPanama);

  test('reconoce variantes de la consulta del XIII', () {
    expect(consultaEsSobreXiii('cuando pagan el decimo tercer mes'), isTrue);
    expect(consultaEsSobreXiii('XIII'), isTrue);
    expect(consultaEsSobreXiii('decimotercer'), isTrue);
    expect(consultaEsSobreXiii('grupo 3'), isFalse);
  });

  test('proximasXiii filtra >= hoy', () {
    final ahora = DateTime.utc(2026, 9, 1, 17, 0); // sep => próxima es dic
    final r = proximasXiii(xiii, ahora: ahora);
    expect(r.first.mes, 'DICIEMBRE');
  });
}
