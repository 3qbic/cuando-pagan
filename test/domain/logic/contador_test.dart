import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/logic/contador.dart';

void main() {
  test('etiquetas de borde', () {
    expect(etiquetaContador(0), 'Es hoy');
    expect(etiquetaContador(1), 'Es mañana');
    expect(etiquetaContador(2), 'Faltan 2 días');
    expect(etiquetaContador(-1), 'Sin fecha próxima');
  });
}
