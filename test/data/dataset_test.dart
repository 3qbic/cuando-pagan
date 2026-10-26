import 'dart:convert';
import 'dart:io';

import 'package:cuando_pagan/data/dataset.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _semilla() =>
    jsonDecode(File('assets/seed/all.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('decodifica la semilla real', () {
    final ds = datasetDesdeAllJson(_semilla(), {});
    expect(ds.calendario.length, 120);
    expect(ds.manifest.dataVersion, 1);
    for (var i = 1; i < ds.xiii.length; i++) {
      expect(ds.xiii[i].fechaDate.isBefore(ds.xiii[i - 1].fechaDate), isFalse);
    }
  });

  test('payload sin calendario no es válido', () {
    expect(payloadValido({..._semilla(), 'calendario': []}), isFalse);
  });

  test('payload sin manifest lanza FormatException', () {
    expect(() => datasetDesdeAllJson({'calendario': []}, {}), throwsFormatException);
  });

  test('HTML decodificado no es válido', () {
    expect(payloadValido({'html': '<!DOCTYPE html>'}), isFalse);
  });

  test('tipos equivocados lanzan FormatException y payloadValido no lanza', () {
    final mal = {..._semilla(), 'calendario': 'x'};
    expect(() => datasetDesdeAllJson(mal, {}), throwsFormatException);
    expect(payloadValido(mal), isFalse);
    expect(payloadValido({..._semilla(), 'manifest': 3}), isFalse);
  });

  test('la semilla completa es válida', () {
    expect(payloadValido(_semilla()), isTrue);
  });
}
