import 'categoria.dart';

class Entidad {
  final String nombreWire; // crudo del dataset, ej. "Min. de Desarrollo Social"
  final String display;    // tildes/expandido para UI, ej. "Ministerio de Desarrollo Social"
  final Categoria grupo;   // join: calendario.categoria == grupos_entidades.grupo
  final List<String> siglas; // capa de la app, ej. ["MIDES"]
  const Entidad({
    required this.nombreWire, required this.display,
    required this.grupo, this.siglas = const [],
  });
}
