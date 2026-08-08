import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/main.dart';

void main() {
  test('anillo décimo: hoy (0 días) => lleno', () {
    expect(progresoAnilloDecimo(0), 1.0);
  });
  test('anillo décimo: 15 días => medio', () {
    expect(progresoAnilloDecimo(15), 0.5);
  });
  test('anillo décimo: 30 días => vacío', () {
    expect(progresoAnilloDecimo(30), 0.0);
  });
  test('anillo décimo: más de 30 días => clamp a 0', () {
    expect(progresoAnilloDecimo(45), 0.0);
  });
  test('anillo décimo: días negativos (ya pasó) => clamp a 1', () {
    expect(progresoAnilloDecimo(-2), 1.0);
  });
}
