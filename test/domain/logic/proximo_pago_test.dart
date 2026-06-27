import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/core/time/tz.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entrada_calendario.dart';
import 'package:cuando_pagan/domain/entities/estado_fecha.dart';
import 'package:cuando_pagan/domain/entities/manifest.dart';
import 'package:cuando_pagan/domain/entities/seleccion.dart';
import 'package:cuando_pagan/domain/logic/proximo_pago.dart';

EntradaCalendario fila(String fechaPago, {int q = 1}) => EntradaCalendario(
      anio: 2026, semestre: 2, mes: 'JULIO', mesNum: 7,
      categoria: Categoria.grupo3, quincena: q,
      inicioRegistro: '', cierreRegistro: '', retencionAch: '',
      fechaPago: fechaPago);

final manifest = const Manifest(
    dataVersion: 1, fechaPublicacion: '2026-06-26',
    semestres: ['2026-S1', '2026-S2'], fuente: 'https://mef',
    totalFilas: 120, conteo: {});

final sel = SeleccionCategoria(Categoria.grupo3);

void main() {
  setUpAll(initZonaPanama);
  final ahora = DateTime.utc(2026, 7, 1, 17, 0); // 12:00 Panamá, 1-jul

  test('elige la primera fecha >= hoy y cuenta días inclusivo', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-23'), fila('2026-07-23'), fila('2026-07-29', q: 2)],
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.entrada!.fechaPago, '2026-07-23');
    expect(pp.estado, EstadoFecha.publicada);
    expect(pp.diasRestantes, 22); // 23-jul menos 1-jul
  });

  test('fecha de hoy => diasRestantes 0 (inclusivo)', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-07-01')],
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.diasRestantes, 0);
    expect(pp.hayFecha, isTrue);
  });

  test('sin fecha futura y misma versión => Pendiente', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-23')],
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.hayFecha, isFalse);
    expect(pp.estado, EstadoFecha.pendiente);
  });

  test('sin fecha futura pero hay versión remota mayor => Desactualizada', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-23')],
      seleccion: sel, manifest: manifest, remoteDataVersion: 2, ahora: ahora);
    expect(pp.estado, EstadoFecha.desactualizada);
  });

  test('última fecha cubierta > 14 días atrás (misma versión) => Desactualizada', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-10')], // 21 días antes del 1-jul
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.estado, EstadoFecha.desactualizada);
  });

  test('borde: última fecha exactamente 14 días atrás => Pendiente (no desactualizada)', () {
    final pp = calcularProximoPago(
      entradasDeCategoria: [fila('2026-06-17')], // 14 días antes del 1-jul, no > 14
      seleccion: sel, manifest: manifest, remoteDataVersion: 1, ahora: ahora);
    expect(pp.estado, EstadoFecha.pendiente);
  });
}
