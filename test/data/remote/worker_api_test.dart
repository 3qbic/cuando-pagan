import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cuando_pagan/data/remote/worker_api.dart';

void main() {
  test('versionCheck parsea /v1/version', () async {
    final client = MockClient((req) async {
      expect(req.url.path, '/v1/version');
      return http.Response(jsonEncode({
        'data_version': 3, 'fecha_publicacion': '2026-06-26',
        'semestres': ['2026-S1', '2026-S2'], 'total_filas': 120,
      }), 200);
    });
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final v = await api.versionCheck();
    expect(v.dataVersion, 3);
    expect(v.semestres, contains('2026-S2'));
  });

  test('fetchAll envía If-None-Match y maneja 304', () async {
    final client = MockClient((req) async {
      expect(req.headers['If-None-Match'], '"v3"');
      return http.Response('', 304);
    });
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final r = await api.fetchAll(etag: '"v3"');
    expect(r.notModified, isTrue);
    expect(r.payload, isNull);
  });

  test('fetchAll 200 mapea calendario, grupos y xiii', () async {
    final body = {
      'manifest': {
        'data_version': 3, 'fecha_publicacion': '2026-06-26',
        'semestres': ['2026-S2'], 'fuente': 'https://mef', 'total_filas': 1, 'conteo': {}
      },
      'calendario': [{
        'anio': 2026, 'semestre': 2, 'mes': 'JULIO', 'mes_num': 7,
        'categoria': 'GRUPO 3', 'quincena': 1, 'inicio_registro': '2026-06-24',
        'cierre_registro': '2026-07-08', 'retencion_ach': '2026-07-15',
        'fecha_pago': '2026-07-23'
      }],
      'grupos_entidades': [{'grupo': 'GRUPO 3', 'entidad': 'Min. de Desarrollo Social'}],
      'xiii_mes': [{'anio': 2026, 'semestre': 2, 'mes': 'AGOSTO', 'fecha_aprox': '2026-08-06'}],
    };
    final client = MockClient((req) async =>
        http.Response(jsonEncode(body), 200, headers: {'etag': '"v3"'}));
    final api = WorkerApi(client, baseUrl: 'https://w.test');
    final r = await api.fetchAll();
    expect(r.notModified, isFalse);
    expect(r.etag, '"v3"');
    expect(r.payload!.calendario.single.fechaPago, '2026-07-23');
    expect(r.payload!.entidades.single.grupo.wire, 'GRUPO 3');
    expect(r.payload!.entidades.single.display, 'Ministerio de Desarrollo Social'); // B9: "Min."→"Ministerio de"
    expect(r.payload!.xiii.single.mes, 'AGOSTO');
  });
}
