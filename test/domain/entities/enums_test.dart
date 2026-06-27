import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';

void main() {
  group('Categoria', () {
    test('mapea wire conocido a display normalizado', () {
      expect(Categoria.fromWire('GRUPO 3'), Categoria.grupo3);
      expect(Categoria.grupo3.display, 'Grupo 3');
      expect(Categoria.fromWire('GASTOS DE REPRESENTACION').display,
          'Gastos de representación');
    });
    test('wire desconocido NO crashea: devuelve null en OrNull', () {
      expect(Categoria.fromWireOrNull('GRUPO 9'), isNull);
    });
  });

  group('EstadoFecha', () {
    test('wire desconocido cae al fallback seguro (publicada)', () {
      expect(EstadoFecha.fromWire('inventado'), EstadoFecha.publicada);
      expect(EstadoFecha.fromWire('modificada'), EstadoFecha.modificada);
    });
  });

  group('Precision', () {
    test('default exacta; reconoce aproximada', () {
      expect(Precision.fromWire('cualquiera'), Precision.exacta);
      expect(Precision.fromWire('aproximada'), Precision.aproximada);
    });
  });
}
