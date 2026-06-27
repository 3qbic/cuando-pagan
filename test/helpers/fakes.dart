import 'dart:convert';
import 'package:cuando_pagan/data/repositories/calendario_repository_impl.dart';

const _semilla2026 = {
  'manifest': {
    'data_version': 1, 'fecha_publicacion': '2026-06-26',
    'semestres': ['2026-S2'], 'fuente': 'https://mef', 'total_filas': 2, 'conteo': {}
  },
  'calendario': [
    {'anio': 2026, 'semestre': 2, 'mes': 'JULIO', 'mes_num': 7, 'categoria': 'GRUPO 3',
     'quincena': 1, 'inicio_registro': '', 'cierre_registro': '', 'retencion_ach': '',
     'fecha_pago': '2026-07-23'},
    {'anio': 2026, 'semestre': 2, 'mes': 'JULIO', 'mes_num': 7, 'categoria': 'GRUPO 1',
     'quincena': 1, 'inicio_registro': '', 'cierre_registro': '', 'retencion_ach': '',
     'fecha_pago': '2026-07-21'},
  ],
  'grupos_entidades': [
    {'grupo': 'GRUPO 3', 'entidad': 'Min. de Desarrollo Social'},
  ],
  'xiii_mes': [
    {'anio': 2026, 'semestre': 2, 'mes': 'AGOSTO', 'fecha_aprox': '2026-08-06'},
  ],
};

class FakeSeed implements FuenteSemilla {
  FakeSeed.dataset2026();
  @override
  Future<Map<String, dynamic>> allJson() async =>
      jsonDecode(jsonEncode(_semilla2026)) as Map<String, dynamic>;
  @override
  Future<Map<String, List<String>>> siglas() async =>
      {'Min. de Desarrollo Social': ['MIDES']};
}

class FakeWorkerApi implements FuenteRemota {
  FakeWorkerApi._(this._remote, this._payload);
  final int _remote;
  final Map<String, dynamic>? _payload;

  factory FakeWorkerApi.sinCambios({required int version}) =>
      FakeWorkerApi._(version, null);

  factory FakeWorkerApi.conActualizacion(
      {required int local, required int remote, bool cambiaFechaG3 = false}) {
    final p = jsonDecode(jsonEncode(_semilla2026)) as Map<String, dynamic>;
    (p['manifest'] as Map)['data_version'] = remote;
    if (cambiaFechaG3) {
      (p['calendario'] as List).first['fecha_pago'] = '2026-07-24';
    }
    return FakeWorkerApi._(remote, p);
  }

  @override
  Future<int> versionRemota() async => _remote;
  @override
  Future<Map<String, dynamic>?> descargarSiCambio(String? etag) async => _payload;
}
