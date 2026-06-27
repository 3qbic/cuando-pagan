class XiiiMes {
  final int anio;
  final int semestre;
  final String mes;        // "FEBRERO"
  final String fechaAprox; // ISO 'YYYY-MM-DD'
  const XiiiMes({
    required this.anio, required this.semestre,
    required this.mes, required this.fechaAprox,
  });
  DateTime get fechaDate => DateTime.parse('${fechaAprox}T00:00:00Z');
}
