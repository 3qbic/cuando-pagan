import '../domain/entities/entidad.dart';
import '../domain/entities/entrada_calendario.dart';
import '../domain/entities/manifest.dart';
import '../domain/entities/xiii_mes.dart';
import 'mappers.dart';

/// Conjunto de datos ya decodificado que consume la UI.
class Dataset {
  final Manifest manifest;
  final List<EntradaCalendario> calendario;
  final List<Entidad> entidades;
  final List<XiiiMes> xiii;
  Dataset(this.manifest, this.calendario, this.entidades, this.xiii);
}

T _clave<T>(Map<String, dynamic> all, String nombre) {
  final v = all[nombre];
  if (v is! T) {
    throw FormatException('Payload /v1/all: "$nombre" falta o no es ${T.toString()}');
  }
  return v;
}

/// Único decode de `/v1/all` (semilla, caché o red). Lanza [FormatException]
/// si faltan claves de primer nivel o tienen un tipo inesperado.
Dataset datasetDesdeAllJson(Map<String, dynamic> all, Map<String, List<String>> siglas) {
  final manifestJson = _clave<Map<String, dynamic>>(all, 'manifest');
  final calJson = _clave<List<dynamic>>(all, 'calendario');
  final gruposJson = _clave<List<dynamic>>(all, 'grupos_entidades');
  final xiiiJson = _clave<List<dynamic>>(all, 'xiii_mes');
  try {
    final manifest = manifestFromJson(manifestJson);
    final cal = calJson.map((e) => entradaFromJson(e as Map<String, dynamic>)).toList();
    final ents = construirEntidades(gruposJson, siglas);
    final xiii = xiiiJson.map((e) => xiiiFromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.fechaDate.compareTo(b.fechaDate));
    return Dataset(manifest, cal, ents, xiii);
  } on FormatException {
    rethrow;
  } catch (e) {
    throw FormatException('Payload /v1/all malformado: $e');
  }
}

/// true si el payload decodifica y trae calendario. Nunca lanza.
bool payloadValido(Map<String, dynamic> all) {
  try {
    return datasetDesdeAllJson(all, const {}).calendario.isNotEmpty;
  } catch (_) {
    return false;
  }
}
