import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/data/mappers.dart';

void main() {
  group('displayEntidad', () {
    test('expande "Min. de" a "Ministerio de"', () {
      expect(displayEntidad('Min. de Desarrollo Social'), 'Ministerio de Desarrollo Social');
    });

    test('agrega tildes a palabras completas', () {
      expect(displayEntidad('Contraloria General'), 'Contraloría General');
      expect(displayEntidad('Min. de Educacion'), 'Ministerio de Educación');
    });

    test('NO daña "Nacional" (regresión: "Nacion"->"Nación" era substring)', () {
      expect(displayEntidad('Asamblea Nacional'), 'Asamblea Nacional');
    });

    test('sí tilda "Nacion" como palabra suelta', () {
      expect(displayEntidad('Procuraduria de la Nacion'), 'Procuraduría de la Nación');
    });

    test('NO daña "Regional" (Region era substring)', () {
      expect(displayEntidad('Direccion Regional'), 'Direccion Regional');
    });
  });
}
