/// Normaliza para comparación: minúsculas, sin diacríticos, sin espacios extremos.
String normalizar(String s) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const sin = 'aaaaaeeeeiiiiooooouuuun';
  var r = s.toLowerCase().trim();
  final b = StringBuffer();
  for (final ch in r.split('')) {
    final i = con.indexOf(ch);
    b.write(i >= 0 ? sin[i] : ch);
  }
  return b.toString();
}
