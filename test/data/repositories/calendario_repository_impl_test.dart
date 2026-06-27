import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';
import 'package:cuando_pagan/data/local/app_database.dart';
import 'package:cuando_pagan/data/repositories/calendario_repository_impl.dart';
import '../../helpers/fakes.dart';

void main() {
  setUpAll(initZonaPanama);

  test('hidrata desde semilla y resuelve próximo pago de GRUPO 3', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = CalendarioRepositoryImpl(
      db: db,
      api: FakeWorkerApi.sinCambios(version: 1),
      seed: FakeSeed.dataset2026(),
      ahora: () => DateTime.utc(2026, 7, 1, 17, 0),
    );
    await repo.asegurarHidratado();
    final pp = await repo.proximoPago(SeleccionCategoria(Categoria.grupo3));
    expect(pp.hayFecha, isTrue);
    expect(pp.estado, EstadoFecha.publicada);
    await db.close();
  });

  test('si remote>local descarga y reporta cambios', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = CalendarioRepositoryImpl(
      db: db,
      api: FakeWorkerApi.conActualizacion(local: 1, remote: 2, cambiaFechaG3: true),
      seed: FakeSeed.dataset2026(),
      ahora: () => DateTime.utc(2026, 7, 1, 17, 0),
    );
    await repo.asegurarHidratado();
    final res = await repo.sincronizar();
    expect(res.descargo, isTrue);
    expect(res.dataVersion, 2);
    expect(res.cambios, isNotEmpty);
    await db.close();
  });
}
