import 'package:cuando_pagan/data/sync/dataset_sync.dart';
import 'package:cuando_pagan/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semilla', () {
    expect(
        textoEstadoDatos(
            const EstadoDatos(origen: OrigenDatos.semilla, dataVersion: 1)),
        'Datos incluidos en la app · versión 1');
  });
  test('caché', () {
    expect(
        textoEstadoDatos(
            const EstadoDatos(origen: OrigenDatos.cache, dataVersion: 2)),
        'Datos guardados · versión 2');
  });
  test('sincronizado', () {
    expect(
        textoEstadoDatos(const EstadoDatos(
            origen: OrigenDatos.sincronizado, dataVersion: 2)),
        'Actualizado · versión 2');
  });
  test('con error añade sin conexión', () {
    expect(
        textoEstadoDatos(const EstadoDatos(
            origen: OrigenDatos.semilla, dataVersion: 1, ultimoError: 'x')),
        'Datos incluidos en la app · versión 1 · sin conexión con el servidor');
  });
  test('textoVersionApp', () {
    expect(textoVersionApp('0.5.0'), 'App versión 0.5.0');
  });
}
