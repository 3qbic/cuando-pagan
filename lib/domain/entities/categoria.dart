/// Las 5 categorías del dataset. `wire` = string EXACTO del Worker (MAYÚSCULAS).
enum Categoria {
  jubilados('JUBILADOS', 'Jubilados'),
  gastosRepresentacion('GASTOS DE REPRESENTACION', 'Gastos de representación'),
  grupo1('GRUPO 1', 'Grupo 1'),
  grupo2('GRUPO 2', 'Grupo 2'),
  grupo3('GRUPO 3', 'Grupo 3');

  const Categoria(this.wire, this.display);
  final String wire;
  final String display;

  static Categoria? fromWireOrNull(String s) {
    for (final c in Categoria.values) {
      if (c.wire == s) return c;
    }
    return null;
  }

  /// Tolerante: nunca crashea. Si el wire es desconocido, cae a [fallback].
  static Categoria fromWire(String s, {Categoria fallback = Categoria.grupo3}) =>
      fromWireOrNull(s) ?? fallback;
}
