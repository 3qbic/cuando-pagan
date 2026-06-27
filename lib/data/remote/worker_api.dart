import 'dart:convert';
import 'package:http/http.dart' as http;
import '../mappers.dart';
import 'dto.dart';

class WorkerApi {
  WorkerApi(this._client, {required this.baseUrl});
  final http.Client _client;
  final String baseUrl;

  Future<VersionInfo> versionCheck() async {
    final r = await _client.get(Uri.parse('$baseUrl/v1/version'));
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return VersionInfo(
      j['data_version'] as int, j['fecha_publicacion'] as String,
      (j['semestres'] as List).cast<String>(), (j['total_filas'] ?? 0) as int);
  }

  Future<AllResponse> fetchAll({String? etag}) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/v1/all'),
      headers: {if (etag != null) 'If-None-Match': etag},
    );
    if (r.statusCode == 304) return const AllResponse(notModified: true);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    const siglas = <String, List<String>>{}; // las siglas reales las inyecta el repo (Task 11)
    final payload = AllPayload(
      manifestFromJson(j['manifest'] as Map<String, dynamic>),
      (j['calendario'] as List).map((e) => entradaFromJson(e as Map<String, dynamic>)).toList(),
      construirEntidades(j['grupos_entidades'] as List, siglas),
      (j['xiii_mes'] as List).map((e) => xiiiFromJson(e as Map<String, dynamic>)).toList(),
    );
    return AllResponse(notModified: false, etag: r.headers['etag'], payload: payload);
  }
}
