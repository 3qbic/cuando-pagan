import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../../domain/entities/categoria.dart';
import '../../domain/entities/entrada_calendario.dart';
import '../../domain/entities/estado_fecha.dart';
import '../../domain/entities/entidad.dart';
import '../../domain/entities/xiii_mes.dart';

part 'app_database.g.dart';

class Calendario extends Table {
  IntColumn get anio => integer()();
  IntColumn get semestre => integer()();
  TextColumn get mes => text()();
  IntColumn get mesNum => integer()();
  TextColumn get categoria => text()(); // wire
  IntColumn get quincena => integer()();
  TextColumn get inicioRegistro => text()();
  TextColumn get cierreRegistro => text()();
  TextColumn get retencionAch => text()();
  TextColumn get fechaPago => text()();
  TextColumn get estado => text()();
  TextColumn get precision => text()();
}

class GruposEntidades extends Table {
  TextColumn get nombreWire => text()();
  TextColumn get grupo => text()();
}

class XiiiMesT extends Table {
  IntColumn get anio => integer()();
  IntColumn get semestre => integer()();
  TextColumn get mes => text()();
  TextColumn get fechaAprox => text()();
}

@DriftDatabase(tables: [Calendario, GruposEntidades, XiiiMesT])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'cuando_pagan'));
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<void> reemplazarCalendario(List<EntradaCalendario> filas) async {
    await transaction(() async {
      await delete(calendario).go();
      await batch((b) => b.insertAll(calendario, filas.map(_toRow)));
    });
  }

  CalendarioCompanion _toRow(EntradaCalendario e) => CalendarioCompanion.insert(
        anio: e.anio, semestre: e.semestre, mes: e.mes, mesNum: e.mesNum,
        categoria: e.categoria.wire, quincena: e.quincena,
        inicioRegistro: e.inicioRegistro, cierreRegistro: e.cierreRegistro,
        retencionAch: e.retencionAch, fechaPago: e.fechaPago,
        estado: e.estado.name, precision: e.precision.name,
      );

  EntradaCalendario _fromRow(CalendarioData r) => EntradaCalendario(
        anio: r.anio, semestre: r.semestre, mes: r.mes, mesNum: r.mesNum,
        categoria: Categoria.fromWire(r.categoria), quincena: r.quincena,
        inicioRegistro: r.inicioRegistro, cierreRegistro: r.cierreRegistro,
        retencionAch: r.retencionAch, fechaPago: r.fechaPago,
        estado: EstadoFecha.fromWire(r.estado),
        precision: Precision.fromWire(r.precision),
      );

  Future<List<EntradaCalendario>> entradasDeCategoria(Categoria c) async {
    final q = select(calendario)..where((t) => t.categoria.equals(c.wire));
    return (await q.get()).map(_fromRow).toList();
  }

  Future<List<EntradaCalendario>> todas() async =>
      (await select(calendario).get()).map(_fromRow).toList();

  Future<void> guardarGrupos(List<Entidad> ents) async {
    await transaction(() async {
      await delete(gruposEntidades).go();
      await batch((b) => b.insertAll(gruposEntidades, ents.map((e) =>
          GruposEntidadesCompanion.insert(nombreWire: e.nombreWire, grupo: e.grupo.wire))));
    });
  }

  Future<List<String>> nombresGruposCrudos() async =>
      (await select(gruposEntidades).get()).map((r) => '${r.nombreWire}|${r.grupo}').toList();

  Future<void> guardarXiii(List<XiiiMes> xs) async {
    await transaction(() async {
      await delete(xiiiMesT).go();
      await batch((b) => b.insertAll(xiiiMesT, xs.map((x) =>
          XiiiMesTCompanion.insert(
              anio: x.anio, semestre: x.semestre, mes: x.mes, fechaAprox: x.fechaAprox))));
    });
  }

  Future<List<XiiiMes>> xiiiTodas() async => (await select(xiiiMesT).get())
      .map((r) => XiiiMes(anio: r.anio, semestre: r.semestre, mes: r.mes, fechaAprox: r.fechaAprox))
      .toList();
}
