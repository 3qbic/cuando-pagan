import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';
import 'package:cuando_pagan/domain/entities/evento_pago.dart';
import 'package:cuando_pagan/domain/entities/manifest.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';
import 'package:cuando_pagan/domain/entities/xiii_mes.dart';
import 'package:cuando_pagan/domain/logic/proximo_evento.dart';

EntradaCalendario fila(String fechaPago,
        {int q = 1, EstadoFecha estado = EstadoFecha.publicada}) =>
    EntradaCalendario(
        anio: 2026, semestre: 2, mes: 'AGOSTO', mesNum: 8,
        categoria: Categoria.grupo3, quincena: q,
        inicioRegistro: '', cierreRegistro: '', retencionAch: '',
        fechaPago: fechaPago, estado: estado);

XiiiMes xiiiEn(String fecha) =>
    XiiiMes(anio: 2026, semestre: 2, mes: 'AGOSTO', fechaAprox: fecha);

const manifest = Manifest(
    dataVersion: 1, fechaPublicacion: '2026-06-26',
    semestres: ['2026-S1', '2026-S2'], fuente: 'https://mef',
    totalFilas: 120, conteo: {});

final sel = SeleccionCategoria(Categoria.grupo3);

ResultadoProximoEvento calc({
  List<EntradaCalendario> filas = const [],
  List<XiiiMes> xiii = const [],
  DateTime? ahora,
}) =>
    calcularProximoEvento(
        entradasDeCategoria: filas, xiii: xiii, seleccion: sel,
        manifest: manifest, remoteDataVersion: 1, ahora: ahora);

void main() {
  setUpAll(initZonaPanama);
  // 12:00 en Panamá del 1-ago-2026 (UTC-5)
  final ahora = DateTime.utc(2026, 8, 1, 17, 0);

  test('caso real 6-ago: el décimo gana a la quincena', () {
    final r = calc(
        filas: [fila('2026-08-14')], xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.esDecimo, isTrue);
    expect(r.proximo!.esQuincena, isFalse);
    expect(r.proximo!.diasRestantes, 5);
    expect(r.proximo!.xiii, isNotNull);
    expect(r.proximo!.entrada, isNull);
  });

  test('quincena más cercana que el décimo => gana quincena', () {
    final r = calc(
        filas: [fila('2026-08-05')], xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.esQuincena, isTrue);
    expect(r.proximo!.esDecimo, isFalse);
    expect(r.proximo!.diasRestantes, 4);
  });

  test('empate exacto de fechas => un evento con ambos tipos', () {
    final r = calc(
        filas: [fila('2026-08-06')], xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.esQuincena, isTrue);
    expect(r.proximo!.esDecimo, isTrue);
    expect(r.proximo!.tipos, {TipoEvento.quincena, TipoEvento.decimo});
  });

  test('hoy es día de pago => diasRestantes 0 y sin recienPasado', () {
    final r = calc(
        filas: [fila('2026-07-29')], // pasó hace 3 días (dentro de ventana)
        xiii: [xiiiEn('2026-08-01')],
        ahora: ahora);
    expect(r.proximo!.diasRestantes, 0);
    expect(r.recienPasado, isNull); // hoy manda
  });

  test('estado: quincena modificada conserva su estado', () {
    final r = calc(
        filas: [fila('2026-08-10', estado: EstadoFecha.modificada)],
        ahora: ahora);
    expect(r.proximo!.estado, EstadoFecha.modificada);
  });

  test('estado: décimo solo => publicada', () {
    final r = calc(xiii: [xiiiEn('2026-08-06')], ahora: ahora);
    expect(r.proximo!.estado, EstadoFecha.publicada);
  });

  test('zona fija: mismo resultado con ahora en otras horas UTC del día', () {
    // 23:30 UTC del 1-ago aún es 18:30 en Panamá => mismo "hoy"
    final r1 = calc(xiii: [xiiiEn('2026-08-06')],
        ahora: DateTime.utc(2026, 8, 1, 23, 30));
    final r2 = calc(xiii: [xiiiEn('2026-08-06')],
        ahora: DateTime.utc(2026, 8, 1, 11, 0));
    expect(r1.proximo!.diasRestantes, r2.proximo!.diasRestantes);
  });
}
