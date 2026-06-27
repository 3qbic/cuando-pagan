class Manifest {
  final int dataVersion;
  final String fechaPublicacion;
  final List<String> semestres;
  final String fuente;
  final int totalFilas;
  final Map<String, int> conteo;
  final List<Cambio>? cambios;
  const Manifest({
    required this.dataVersion, required this.fechaPublicacion,
    required this.semestres, required this.fuente, required this.totalFilas,
    required this.conteo, this.cambios,
  });
}

class Cambio {
  final String clave; // slotKey
  final String fechaAnterior;
  final String fechaNueva;
  final int desdeVersion;
  const Cambio({
    required this.clave, required this.fechaAnterior,
    required this.fechaNueva, required this.desdeVersion,
  });
}
