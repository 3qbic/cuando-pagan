import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/version.dart';

void main() {
  test('kVersionApp/kBuildApp coinciden con pubspec.yaml (sube las dos al publicar)', () {
    final m = RegExp(r'^version:\s*(\S+)\+(\d+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!;
    expect(kVersionApp, m.group(1));
    expect(kBuildApp, int.parse(m.group(2)!));
  });
}
