/// Estados de una fecha. `estimada` existe pero NUNCA se emite en v1 (Fase 2).
enum EstadoFecha {
  publicada, modificada, pendiente, desactualizada, estimada;

  static EstadoFecha fromWire(String s, {EstadoFecha fallback = EstadoFecha.publicada}) {
    for (final e in EstadoFecha.values) {
      if (e.name == s.toLowerCase()) return e;
    }
    return fallback;
  }
}

/// Atributo ortogonal al estado. El XIII Mes es 'aproximada'.
enum Precision {
  exacta, aproximada;

  static Precision fromWire(String s, {Precision fallback = Precision.exacta}) {
    for (final p in Precision.values) {
      if (p.name == s.toLowerCase()) return p;
    }
    return fallback;
  }
}
