import 'package:flutter_test/flutter_test.dart';
import 'package:cuando_pagan/domain/entities/categoria.dart';
import 'package:cuando_pagan/domain/entities/entidad.dart';
import 'package:cuando_pagan/domain/search/buscador_entidades.dart';
import 'package:cuando_pagan/core/text/normalizar.dart';

final universo = [
  Entidad(nombreWire: 'Min. de Desarrollo Social', display: 'Ministerio de Desarrollo Social', grupo: Categoria.grupo3, siglas: const ['MIDES']),
  Entidad(nombreWire: 'Min. de Educacion', display: 'Ministerio de Educación', grupo: Categoria.grupo1, siglas: const ['MEDUCA']),
  Entidad(nombreWire: 'Organo Judicial', display: 'Órgano Judicial', grupo: Categoria.grupo3, siglas: const ['OJ']),
];

void main() {
  test('normalizar quita acentos y baja a minúsculas', () {
    expect(normalizar('Educación'), 'educacion');
  });

  test('busca por sigla exacta (MIDES)', () {
    final r = buscarEntidades('MIDES', universo);
    expect(r.single.nombreWire, 'Min. de Desarrollo Social');
    expect(r.single.grupo, Categoria.grupo3);
  });

  test('busca por nombre sin acentos (educacion → MEDUCA)', () {
    final r = buscarEntidades('educacion', universo);
    expect(r.single.siglas, contains('MEDUCA'));
  });

  test('query vacía devuelve todo ordenado por display', () {
    final r = buscarEntidades('', universo);
    expect(r.map((e) => e.display).toList(),
        ['Ministerio de Desarrollo Social', 'Ministerio de Educación', 'Órgano Judicial']);
  });
}
