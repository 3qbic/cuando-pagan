import 'package:cuando_pagan/data/sync/dataset_sync.dart';
import 'package:cuando_pagan/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semilla', () {
    expect(
        textoEstadoDatos(
            const EstadoDatos(origen: OrigenDatos.semilla, dataVersion: 1)),
        'Calendario de pagos: edición 1 (la que trae la app)');
  });
  test('caché', () {
    expect(
        textoEstadoDatos(
            const EstadoDatos(origen: OrigenDatos.cache, dataVersion: 2)),
        'Calendario de pagos: edición 2 (guardada)');
  });
  test('sincronizado', () {
    expect(
        textoEstadoDatos(const EstadoDatos(
            origen: OrigenDatos.sincronizado, dataVersion: 2)),
        'Calendario de pagos: edición 2 (al día)');
  });
  test('con error añade sin conexión', () {
    expect(
        textoEstadoDatos(const EstadoDatos(
            origen: OrigenDatos.semilla, dataVersion: 1, ultimoError: 'x')),
        'Calendario de pagos: edición 1 (la que trae la app) · sin conexión con el servidor');
  });
  test('textoVersionApp', () {
    expect(textoVersionApp('0.5.6'), 'Versión 0.5.6 · es la más reciente');
    expect(textoVersionApp('0.5.6', nueva: '0.5.7'), 'Versión 0.5.6 · hay una nueva: 0.5.7');
  });
}
