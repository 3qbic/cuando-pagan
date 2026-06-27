import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/core/time/hoy_panama.dart';

void main() {
  setUpAll(initZonaPanama);

  test('a las 23:30 UTC del 26-jun el día en Panamá (UTC-5) sigue siendo 26-jun', () {
    final ahora = DateTime.utc(2026, 6, 26, 23, 30); // 18:30 en Panamá
    expect(hoyPanamaIso(ahora: ahora), '2026-06-26');
  });

  test('a las 04:30 UTC del 27-jun en Panamá aún es 26-jun (23:30 del 26)', () {
    final ahora = DateTime.utc(2026, 6, 27, 4, 30); // 23:30 del 26 en Panamá
    expect(hoyPanamaIso(ahora: ahora), '2026-06-26');
  });

  test('a las 05:30 UTC del 27-jun en Panamá ya es 27-jun (00:30)', () {
    final ahora = DateTime.utc(2026, 6, 27, 5, 30); // 00:30 del 27 en Panamá
    expect(hoyPanamaIso(ahora: ahora), '2026-06-27');
  });
}
