import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/umbrales.dart';
import '../dataset.dart';

enum OrigenDatos { semilla, cache, sincronizado }

class EstadoDatos {
  final OrigenDatos origen;
  final int dataVersion;
  final String? ultimoError;
  final DateTime? ultimoIntento;
  const EstadoDatos({
    required this.origen,
    required this.dataVersion,
    this.ultimoError,
    this.ultimoIntento,
  });
}

/// URL de `/v1/version` con solo dimensiones agregadas (plataforma, versión de
/// app, versión de datos, push). Sin IDs, nonces ni marcas de tiempo.
Uri uriVersion(
  String baseUrl, {
  required String plataforma,
  required String appVersion,
  required int dataVersion,
  required bool push,
}) =>
    Uri.parse('$baseUrl/v1/version').replace(queryParameters: {
      'p': plataforma,
      'v': appVersion,
      'd': '$dataVersion',
      'push': push ? '1' : '0',
    });

/// Datos offline-first: arranca con el caché de `/v1/all` o la semilla
/// empaquetada, y sincroniza con el Worker cuando hay una versión más nueva.
class DatasetSync {
  static const claveCacheJson = 'cacheAllJson';
  static const claveCacheVersion = 'cacheDataVersion';

  final http.Client _client;
  final SharedPreferences _prefs;
  final Future<Map<String, dynamic>> Function() _leerSemilla;
  final Map<String, List<String>> _siglas;
  final String _baseUrl;
  final Duration _timeout;
  final String _plataforma;
  final String _appVersion;

  EstadoDatos _estado = const EstadoDatos(origen: OrigenDatos.semilla, dataVersion: 0);
  bool _inicializado = false;

  DatasetSync({
    required http.Client client,
    required SharedPreferences prefs,
    required Future<Map<String, dynamic>> Function() leerSemilla,
    required Map<String, List<String>> siglas,
    String baseUrl = kWorkerBaseUrl,
    Duration timeout = const Duration(seconds: 8),
    String plataforma = 'web',
    String appVersion = 'desconocido',
  })  : _client = client,
        _prefs = prefs,
        _leerSemilla = leerSemilla,
        _siglas = siglas,
        _baseUrl = baseUrl,
        _timeout = timeout,
        _plataforma = plataforma,
        _appVersion = appVersion;

  EstadoDatos get estado => _estado;

  void _setEstado({OrigenDatos? origen, int? dataVersion, String? error, bool limpiarError = false}) {
    _estado = EstadoDatos(
      origen: origen ?? _estado.origen,
      dataVersion: dataVersion ?? _estado.dataVersion,
      ultimoError: limpiarError ? null : (error ?? _estado.ultimoError),
      ultimoIntento: _estado.ultimoIntento,
    );
  }

  Null _fallo(String msg) {
    debugPrint('[sync] $msg');
    _estado = EstadoDatos(
      origen: _estado.origen,
      dataVersion: _estado.dataVersion,
      ultimoError: msg,
      ultimoIntento: DateTime.now(),
    );
    return null;
  }

  Future<Dataset> cargarInicial() async {
    final semillaJson = await _leerSemilla();
    final semilla = datasetDesdeAllJson(semillaJson, _siglas);

    final cacheStr = _prefs.getString(claveCacheJson);
    final cacheVer = _prefs.getInt(claveCacheVersion);
    if (cacheStr != null || cacheVer != null) {
      if (cacheStr != null && cacheVer != null && cacheVer > semilla.manifest.dataVersion) {
        try {
          final decoded = jsonDecode(cacheStr);
          if (decoded is Map<String, dynamic> && payloadValido(decoded)) {
            final d = datasetDesdeAllJson(decoded, _siglas);
            _inicializado = true;
            _estado = EstadoDatos(origen: OrigenDatos.cache, dataVersion: d.manifest.dataVersion);
            return d;
          }
        } catch (e) {
          debugPrint('[sync] caché ilegible: ${e.runtimeType}');
        }
        debugPrint('[sync] caché inválido, se descarta');
        await _prefs.remove(claveCacheJson);
        await _prefs.remove(claveCacheVersion);
      } else if (cacheStr == null || cacheVer == null) {
        // Estado a medias: limpiar para no arrastrar basura.
        await _prefs.remove(claveCacheJson);
        await _prefs.remove(claveCacheVersion);
      }
      // Caché válido pero más viejo que la semilla: se ignora y se deja.
    }

    _inicializado = true;
    _estado = EstadoDatos(origen: OrigenDatos.semilla, dataVersion: semilla.manifest.dataVersion);
    return semilla;
  }

  Future<Dataset?> sincronizar() async {
    try {
      return await _sincronizar();
    } catch (e) {
      return _fallo('error inesperado: ${e.runtimeType}');
    }
  }

  Future<Dataset?> _sincronizar() async {
    if (!_inicializado) return _fallo('sincronizar() antes de cargarInicial()');
    final local = _estado.dataVersion;

    final http.Response rv;
    try {
      rv = await _client
          .get(uriVersion(_baseUrl,
              plataforma: _plataforma, appVersion: _appVersion, dataVersion: local, push: false)).timeout(_timeout);
    } catch (e) {
      return _fallo('/v1/version falló: ${e.runtimeType}');
    }
    if (rv.statusCode != 200) return _fallo('/v1/version respondió ${rv.statusCode}');
    if (!(rv.headers['content-type'] ?? '').contains('application/json')) {
      return _fallo('/v1/version no devolvió JSON');
    }
    final int remota;
    try {
      final v = jsonDecode(rv.body);
      final dv = v is Map ? v['data_version'] : null;
      if (dv is! int) return _fallo('/v1/version sin data_version entero');
      remota = dv;
    } catch (_) {
      return _fallo('/v1/version JSON inválido');
    }

    _setEstado(limpiarError: true);
    if (remota <= local) {
      _estado = EstadoDatos(
          origen: _estado.origen, dataVersion: _estado.dataVersion, ultimoIntento: DateTime.now());
      return null;
    }

    final http.Response ra;
    try {
      ra = await _client
          .get(Uri.parse('$_baseUrl/v1/all'), headers: {'If-None-Match': '"v$local"'})
          .timeout(_timeout);
    } catch (e) {
      return _fallo('/v1/all falló: ${e.runtimeType}');
    }
    if (ra.statusCode == 304) {
      _estado = EstadoDatos(
          origen: _estado.origen, dataVersion: _estado.dataVersion, ultimoIntento: DateTime.now());
      return null;
    }
    if (ra.statusCode != 200) return _fallo('/v1/all respondió ${ra.statusCode}');

    final Map<String, dynamic> all;
    try {
      final decoded = jsonDecode(utf8.decode(ra.bodyBytes));
      if (decoded is! Map<String, dynamic>) return _fallo('/v1/all no es un objeto JSON');
      all = decoded;
    } catch (_) {
      return _fallo('/v1/all JSON inválido');
    }
    if (!payloadValido(all)) return _fallo('/v1/all no pasó la validación');
    final Dataset d;
    try {
      d = datasetDesdeAllJson(all, _siglas);
    } catch (e) {
      return _fallo('/v1/all no decodifica: ${e.runtimeType}');
    }
    final nueva = d.manifest.dataVersion;
    if (nueva <= local) return _fallo('/v1/all trae data_version $nueva <= local $local');

    await _prefs.setString(claveCacheJson, utf8.decode(ra.bodyBytes));
    await _prefs.setInt(claveCacheVersion, nueva);
    _estado = EstadoDatos(
      origen: OrigenDatos.sincronizado,
      dataVersion: nueva,
      ultimoIntento: DateTime.now(),
    );
    debugPrint('[sync] actualizado a v$nueva');
    return d;
  }
}
