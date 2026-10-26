import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cuando_pagan/data/sync/dataset_sync.dart';

const _base = 'https://w.test';

Map<String, dynamic> _seed({int version = 1}) {
  final m = jsonDecode(File('assets/seed/all.json').readAsStringSync()) as Map<String, dynamic>;
  (m['manifest'] as Map<String, dynamic>)['data_version'] = version;
  return m;
}

http.Response _json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json; charset=utf-8'});

Future<DatasetSync> _sync(
  MockClient client, {
  int semilla = 1,
  Map<String, Object> prefsIniciales = const {},
  Duration timeout = const Duration(seconds: 8),
  String? appVersion,
}) async {
  SharedPreferences.setMockInitialValues(prefsIniciales);
  final prefs = await SharedPreferences.getInstance();
  return DatasetSync(
    client: client,
    prefs: prefs,
    leerSemilla: () async => _seed(version: semilla),
    siglas: const {},
    baseUrl: _base,
    timeout: timeout,
    appVersion: appVersion ?? 'desconocido',
  );
}

MockClient _noRed() => MockClient((req) async => fail('No debía haber red: ${req.url}'));

MockClient _remoto({required int version, Map<String, dynamic>? all, void Function(http.Request)? onAll}) =>
    MockClient((req) async {
      if (req.url.path == '/v1/version') return _json({'data_version': version});
      if (req.url.path == '/v1/all') {
        onAll?.call(req);
        return _json(all ?? _seed(version: version));
      }
      return http.Response('', 404);
    });

void main() {
  group('cargarInicial', () {
    test('sin caché arranca con la semilla', () async {
      final s = await _sync(_noRed());
      final d = await s.cargarInicial();
      expect(s.estado.origen, OrigenDatos.semilla);
      expect(s.estado.dataVersion, 1);
      expect(d.calendario, isNotEmpty);
    });

    test('caché v2 válido gana sobre semilla v1', () async {
      final s = await _sync(_noRed(), prefsIniciales: {
        'cacheAllJson': jsonEncode(_seed(version: 2)),
        'cacheDataVersion': 2,
      });
      await s.cargarInicial();
      expect(s.estado.origen, OrigenDatos.cache);
      expect(s.estado.dataVersion, 2);
    });

    test('semilla más nueva que el caché gana la semilla', () async {
      final s = await _sync(_noRed(), semilla: 2, prefsIniciales: {
        'cacheAllJson': jsonEncode(_seed(version: 1)),
        'cacheDataVersion': 1,
      });
      await s.cargarInicial();
      expect(s.estado.origen, OrigenDatos.semilla);
      expect(s.estado.dataVersion, 2);
    });

    test('caché corrupto se descarta', () async {
      final s = await _sync(_noRed(), prefsIniciales: {
        'cacheAllJson': '{"manif',
        'cacheDataVersion': 5,
      });
      await s.cargarInicial();
      expect(s.estado.origen, OrigenDatos.semilla);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cacheAllJson'), isNull);
      expect(prefs.getInt('cacheDataVersion'), isNull);
    });
  });

  group('sincronizar', () {
    test('version devuelve HTML: no crashea ni cachea', () async {
      final c = MockClient((req) async =>
          http.Response('<!DOCTYPE html><html></html>', 200, headers: {'content-type': 'text/html'}));
      final s = await _sync(c);
      await s.cargarInicial();
      expect(await s.sincronizar(), isNull);
      expect(s.estado.ultimoError, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cacheAllJson'), isNull);
    });

    test('remoto igual al local no descarga /v1/all', () async {
      final c = MockClient((req) async {
        if (req.url.path == '/v1/all') fail('No debía pedir /v1/all');
        return _json({'data_version': 1});
      });
      final s = await _sync(c);
      await s.cargarInicial();
      expect(await s.sincronizar(), isNull);
      expect(s.estado.ultimoError, isNull);
    });

    test('remoto mayor descarga, valida y cachea', () async {
      http.Request? reqAll;
      final s = await _sync(_remoto(version: 2, onAll: (r) => reqAll = r));
      await s.cargarInicial();
      final d = await s.sincronizar();
      expect(d, isNotNull);
      expect(d!.manifest.dataVersion, 2);
      expect(s.estado.origen, OrigenDatos.sincronizado);
      expect(s.estado.dataVersion, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('cacheDataVersion'), 2);
      expect(prefs.getString('cacheAllJson'), isNotNull);
      expect(reqAll!.headers['If-None-Match'], '"v1"');
    });

    test('tras sincronizar, la siguiente comparación usa la versión nueva', () async {
      final s = await _sync(_remoto(version: 2));
      await s.cargarInicial();
      expect(await s.sincronizar(), isNotNull);
      expect(await s.sincronizar(), isNull);
      expect(s.estado.ultimoError, isNull);
    });

    test('all con 304 devuelve null', () async {
      final c = MockClient((req) async => req.url.path == '/v1/version'
          ? _json({'data_version': 2})
          : http.Response('', 304));
      final s = await _sync(c);
      await s.cargarInicial();
      expect(await s.sincronizar(), isNull);
    });

    test('all con calendario vacío no reemplaza', () async {
      final vacio = _seed(version: 2)..['calendario'] = [];
      final s = await _sync(_remoto(version: 2, all: vacio));
      await s.cargarInicial();
      expect(await s.sincronizar(), isNull);
      expect(s.estado.ultimoError, isNotNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cacheAllJson'), isNull);
    });

    test('all con data_version menor no reemplaza', () async {
      final s = await _sync(_remoto(version: 3, all: _seed(version: 1)));
      await s.cargarInicial();
      expect(await s.sincronizar(), isNull);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('cacheAllJson'), isNull);
    });

    test('timeout no lanza', () async {
      final c = MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return _json({'data_version': 2});
      });
      final s = await _sync(c, timeout: const Duration(milliseconds: 20));
      await s.cargarInicial();
      expect(await s.sincronizar(), isNull);
      expect(s.estado.ultimoError, isNotNull);
    });

    test('sincronizar antes de cargarInicial no lanza', () async {
      final s = await _sync(_noRed());
      expect(await s.sincronizar(), isNull);
      expect(s.estado.ultimoError, isNotNull);
    });
  });

  group('parámetros de apertura', () {
    test('uriVersion arma p, v, d y push en ese orden', () {
      expect(
          uriVersion('https://w.test', plataforma: 'web', appVersion: '0.5.0', dataVersion: 1, push: false)
              .toString(),
          'https://w.test/v1/version?p=web&v=0.5.0&d=1&push=0');
    });

    test('/v1/version lleva los 4 parámetros', () async {
      Map<String, String>? q;
      final c = MockClient((req) async {
        if (req.url.path == '/v1/version') {
          q = req.url.queryParameters;
          return _json({'data_version': 1});
        }
        return http.Response('', 404);
      });
      final s = await _sync(c, appVersion: '0.5.0');
      await s.cargarInicial();
      await s.sincronizar();
      expect(q, {'p': 'web', 'v': '0.5.0', 'd': '1', 'push': '0'});
    });

    test('sin appVersion explícito, v=desconocido', () async {
      Map<String, String>? q;
      final c = MockClient((req) async {
        q = req.url.queryParameters;
        return _json({'data_version': 1});
      });
      final s = await _sync(c);
      await s.cargarInicial();
      await s.sincronizar();
      expect(q!['v'], 'desconocido');
    });
  });
}
