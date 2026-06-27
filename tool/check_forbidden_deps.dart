import 'dart:io';

const forbidden = <String>[
  'firebase_analytics', 'firebase_crashlytics', 'sentry_flutter',
  'amplitude', 'google_mobile_ads', 'appsflyer', 'facebook_',
];

List<String> findForbidden(String pubspec) {
  final hits = <String>[];
  for (final name in forbidden) {
    final re = RegExp('^\\s*$name', multiLine: true);
    if (re.hasMatch(pubspec)) hits.add(name);
  }
  return hits;
}

void main() {
  final hits = findForbidden(File('pubspec.yaml').readAsStringSync());
  if (hits.isNotEmpty) {
    stderr.writeln('Dependencias prohibidas (gobernanza no-tracking): $hits');
    exit(1);
  }
  stdout.writeln('OK: sin dependencias prohibidas.');
}
