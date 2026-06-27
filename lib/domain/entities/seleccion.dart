import 'categoria.dart';
import 'entidad.dart';

/// "Mi institución": una Categoría directa o una Entidad (que resuelve a su grupo).
sealed class Seleccion {
  Categoria get categoria;
  String get etiqueta;
  String toToken();

  /// "cat:GRUPO 3" | "ent:Min. de Desarrollo Social"
  static Seleccion? fromToken(String token, List<Entidad> entidades) {
    if (token.startsWith('cat:')) {
      final c = Categoria.fromWireOrNull(token.substring(4));
      return c == null ? null : SeleccionCategoria(c);
    }
    if (token.startsWith('ent:')) {
      final nombre = token.substring(4);
      for (final e in entidades) {
        if (e.nombreWire == nombre) return SeleccionEntidad(e);
      }
    }
    return null;
  }
}

class SeleccionCategoria extends Seleccion {
  final Categoria cat;
  SeleccionCategoria(this.cat);
  @override
  Categoria get categoria => cat;
  @override
  String get etiqueta => cat.display;
  @override
  String toToken() => 'cat:${cat.wire}';
}

class SeleccionEntidad extends Seleccion {
  final Entidad entidad;
  SeleccionEntidad(this.entidad);
  @override
  Categoria get categoria => entidad.grupo;
  @override
  String get etiqueta => entidad.display;
  @override
  String toToken() => 'ent:${entidad.nombreWire}';
}
