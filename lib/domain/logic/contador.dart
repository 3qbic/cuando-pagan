String etiquetaContador(int diasRestantes) {
  if (diasRestantes < 0) return 'Sin fecha próxima';
  if (diasRestantes == 0) return 'Es hoy';
  if (diasRestantes == 1) return 'Es mañana';
  return 'Faltan $diasRestantes días';
}
