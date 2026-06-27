import 'package:timezone/timezone.dart' as tz;
import 'tz.dart';

/// Medianoche de "hoy" en hora de Panamá, normalizada a UTC para comparar fechas.
DateTime hoyPanama({DateTime? ahora}) {
  final base = ahora ?? DateTime.now().toUtc();
  final enPanama = tz.TZDateTime.from(base, panama);
  return DateTime.utc(enPanama.year, enPanama.month, enPanama.day);
}

/// "YYYY-MM-DD" de hoy en Panamá.
String hoyPanamaIso({DateTime? ahora}) {
  final h = hoyPanama(ahora: ahora);
  final mm = h.month.toString().padLeft(2, '0');
  final dd = h.day.toString().padLeft(2, '0');
  return '${h.year}-$mm-$dd';
}
