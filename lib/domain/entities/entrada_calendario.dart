import 'categoria.dart';
import 'estado_fecha.dart';

class EntradaCalendario {
  final int anio;
  final int semestre;
  final String mes;       // "ENERO" (wire)
  final int mesNum;
  final Categoria categoria;
  final int quincena;     // 1 | 2
  final String inicioRegistro;
  final String cierreRegistro;
  final String retencionAch;
  final String fechaPago; // ISO 'YYYY-MM-DD' — DATO PRIMARIO
  final EstadoFecha estado;
  final Precision precision;

  const EntradaCalendario({
    required this.anio, required this.semestre, required this.mes,
    required this.mesNum, required this.categoria, required this.quincena,
    required this.inicioRegistro, required this.cierreRegistro,
    required this.retencionAch, required this.fechaPago,
    this.estado = EstadoFecha.publicada, this.precision = Precision.exacta,
  });

  DateTime get fechaPagoDate => DateTime.parse('${fechaPago}T00:00:00Z');
  String get slotKey => '$anio-S$semestre|$mesNum|${categoria.wire}|$quincena';
}
