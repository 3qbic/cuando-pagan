import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/logic/diff_modificadas.dart';

EntradaCalendario f(int q, String fecha) => EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7,
      categoria: Categoria.grupo3, quincena: q,
      inicioRegistro: '', cierreRegistro: '', retencionAch: '', fechaPago: fecha);

void main() {
  test('detecta cambio de fecha_pago en el mismo slot', () {
    final cambios = detectarModificadas(
      previas: [f(1, '2026-07-23'), f(2, '2026-07-29')],
      nuevas: [f(1, '2026-07-24'), f(2, '2026-07-29')],
      desdeVersion: 1);
    expect(cambios, hasLength(1));
    expect(cambios.single.clave, '2026-S2|7|GRUPO 3|1');
    expect(cambios.single.fechaAnterior, '2026-07-23');
    expect(cambios.single.fechaNueva, '2026-07-24');
  });

  test('sin cambios => lista vacía', () {
    final cambios = detectarModificadas(
      previas: [f(1, '2026-07-23')], nuevas: [f(1, '2026-07-23')], desdeVersion: 1);
    expect(cambios, isEmpty);
  });
}
