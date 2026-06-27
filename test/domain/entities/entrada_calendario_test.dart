import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/entities/entidad.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';

EntradaCalendario _fila() => const EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7,
      categoria: Categoria.grupo3, quincena: 1,
      inicioRegistro: '2026-06-24', cierreRegistro: '2026-07-08',
      retencionAch: '2026-07-15', fechaPago: '2026-07-23');

void main() {
  test('slotKey es estable y único por anio/sem/mes/categoria/quincena', () {
    expect(_fila().slotKey, '2026-S2|7|GRUPO 3|1');
  });

  test('fechaPagoDate parsea ISO a UTC medianoche', () {
    expect(_fila().fechaPagoDate, DateTime.utc(2026, 7, 23));
  });

  test('Seleccion roundtrip por token', () {
    final ent = Entidad(
        nombreWire: 'Min. de Desarrollo Social',
        display: 'Ministerio de Desarrollo Social',
        grupo: Categoria.grupo3, siglas: const ['MIDES']);
    final sel = SeleccionEntidad(ent);
    final token = sel.toToken();
    final back = Seleccion.fromToken(token, [ent]);
    expect(back, isA<SeleccionEntidad>());
    expect(back!.categoria, Categoria.grupo3);
    expect(Seleccion.fromToken('cat:GRUPO 1', const []), isA<SeleccionCategoria>());
  });
}
