import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuando_pagan/core/pwa/pwa.dart';
import 'package:cuando_pagan/main.dart';

Future<void> _montar(WidgetTester t, EstadoPwa e) async {
  await t.pumpWidget(MaterialApp(home: Scaffold(body: AvisoInstalar(estadoInicial: e))));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('iPhone: instrucciones de Safari y calculadora web', (t) async {
    await _montar(t, EstadoPwa.ios);
    expect(find.textContaining('Agregar a inicio'), findsOneWidget);
    expect(find.textContaining('calculadora web'), findsOneWidget);
    expect(find.text('Instalar'), findsNothing);
  });

  testWidgets('Android con prompt: botón Instalar y enlace a Google Play', (t) async {
    await _montar(t, EstadoPwa.androidPrompt);
    expect(find.text('Instalar'), findsOneWidget);
    expect(find.textContaining('Google Play'), findsOneWidget);
  });

  testWidgets('Android sin prompt: instrucciones del menú de Chrome', (t) async {
    await _montar(t, EstadoPwa.android);
    expect(find.textContaining('menú ⋮'), findsOneWidget);
    expect(find.text('Instalar'), findsNothing);
  });

  testWidgets('ya instalada o escritorio: no se muestra', (t) async {
    await _montar(t, EstadoPwa.standalone);
    expect(find.textContaining('pantalla de inicio'), findsNothing);
    await _montar(t, EstadoPwa.otro);
    expect(find.textContaining('pantalla de inicio'), findsNothing);
  });

  testWidgets('al cerrarlo se oculta y se recuerda', (t) async {
    await _montar(t, EstadoPwa.ios);
    await t.tap(find.byTooltip('Cerrar aviso'));
    await t.pumpAndSettle();
    expect(find.textContaining('pantalla de inicio'), findsNothing);
    final p = await SharedPreferences.getInstance();
    expect(p.getBool('aviso_instalar_cerrado_v1'), isTrue);
  });

  testWidgets('si ya lo cerró antes, no vuelve a salir', (t) async {
    SharedPreferences.setMockInitialValues({'aviso_instalar_cerrado_v1': true});
    await _montar(t, EstadoPwa.androidPrompt);
    expect(find.text('Instalar'), findsNothing);
  });
}
