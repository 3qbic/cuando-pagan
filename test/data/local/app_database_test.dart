import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/data/local/app_database.dart';

EntradaCalendario f(Categoria c, String fecha, {int q = 1}) => EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7, categoria: c, quincena: q,
      inicioRegistro: '', cierreRegistro: '', retencionAch: '', fechaPago: fecha);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('reemplazar + consultar por categoría', () async {
    await db.reemplazarCalendario([
      f(Categoria.grupo3, '2026-07-23'), f(Categoria.grupo1, '2026-07-21'),
    ]);
    final g3 = await db.entradasDeCategoria(Categoria.grupo3);
    expect(g3, hasLength(1));
    expect(g3.single.fechaPago, '2026-07-23');
  });

  test('swap atómico reemplaza todo el contenido', () async {
    await db.reemplazarCalendario([f(Categoria.grupo3, '2026-07-23')]);
    await db.reemplazarCalendario([f(Categoria.grupo3, '2026-08-24')]);
    final g3 = await db.entradasDeCategoria(Categoria.grupo3);
    expect(g3.single.fechaPago, '2026-08-24');
  });
}
