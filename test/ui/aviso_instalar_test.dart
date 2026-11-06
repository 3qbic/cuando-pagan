import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuando_pagan/core/pwa/pwa.dart';
import 'package:cuando_pagan/main.dart';

final _hoy = DateTime(2026, 11, 6);

Future<void> _montar(WidgetTester t, EstadoPwa e, {DateTime? hoy}) async {
  await t.pumpWidget(const SizedBox()); // estado nuevo en cada montaje
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Stack(children: [
        Positioned(left: 0, right: 0, bottom: 0,
            child: BarraInstalar(estadoInicial: e, retrasoPrimeraVisita: Duration.zero, hoy: hoy ?? _hoy)),
      ]),
    ),
  ));
  await t.pumpAndSettle();
}

bool _visible(WidgetTester t) =>
    t.widget<AnimatedOpacity>(find.descendant(of: find.byType(BarraInstalar), matching: find.byType(AnimatedOpacity))).opacity == 1;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Android con prompt: aparece la barra con Instalar', (t) async {
    await _montar(t, EstadoPwa.androidPrompt);
    expect(_visible(t), isTrue);
    expect(find.text('Instala ¿Cuándo Pagan?'), findsOneWidget);
    expect(find.text('Instalar'), findsOneWidget);
  });

  testWidgets('iPhone: Instalar abre la hoja con los pasos de Safari', (t) async {
    await _montar(t, EstadoPwa.ios);
    await t.tap(find.text('Instalar'));
    await t.pumpAndSettle();
    expect(find.text('Instálala en tu iPhone'), findsOneWidget);
    expect(find.textContaining('Agregar a inicio'), findsOneWidget);
  });

  testWidgets('Android sin prompt: la hoja explica el menú de Chrome', (t) async {
    await _montar(t, EstadoPwa.android);
    await t.tap(find.text('Instalar'));
    await t.pumpAndSettle();
    expect(find.textContaining('menú ⋮'), findsOneWidget);
  });

  testWidgets('ya instalada o escritorio: no aparece', (t) async {
    await _montar(t, EstadoPwa.standalone);
    expect(_visible(t), isFalse);
    await _montar(t, EstadoPwa.otro);
    expect(_visible(t), isFalse);
  });

  testWidgets('"Ahora no" la oculta y la pospone 14 días', (t) async {
    await _montar(t, EstadoPwa.ios);
    await t.tap(find.byTooltip('Ahora no'));
    await t.pumpAndSettle();
    expect(_visible(t), isFalse);
    final p = await SharedPreferences.getInstance();
    expect(DateTime.parse(p.getString('pwa_pospuesto_hasta_v1')!), _hoy.add(const Duration(days: 14)));
  });

  testWidgets('pospuesta: no sale antes de la fecha y vuelve a salir después', (t) async {
    SharedPreferences.setMockInitialValues({'pwa_pospuesto_hasta_v1': DateTime(2026, 11, 20).toIso8601String()});
    await _montar(t, EstadoPwa.androidPrompt);
    expect(_visible(t), isFalse);
    await _montar(t, EstadoPwa.androidPrompt, hoy: DateTime(2026, 11, 21));
    expect(_visible(t), isTrue);
  });

  testWidgets('cuenta las visitas', (t) async {
    await _montar(t, EstadoPwa.otro);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('pwa_visitas_v1'), 1);
  });
}
