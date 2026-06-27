import 'package:flutter_test/flutter_test.dart';
import '../../tool/check_forbidden_deps.dart' as checker;

void main() {
  test('detecta una dependencia prohibida', () {
    final hits = checker.findForbidden('''
dependencies:
  http: ^1.2.2
  firebase_analytics: ^11.0.0
''');
    expect(hits, contains('firebase_analytics'));
  });

  test('pubspec limpio no reporta nada', () {
    final hits = checker.findForbidden('''
dependencies:
  http: ^1.2.2
  drift: ^2.18.0
''');
    expect(hits, isEmpty);
  });
}
