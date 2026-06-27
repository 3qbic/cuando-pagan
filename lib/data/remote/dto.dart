import '../../domain/entities/entidad.dart';
import '../../domain/entities/entrada_calendario.dart';
import '../../domain/entities/manifest.dart';
import '../../domain/entities/xiii_mes.dart';

class VersionInfo {
  final int dataVersion;
  final String fechaPublicacion;
  final List<String> semestres;
  final int totalFilas;
  const VersionInfo(this.dataVersion, this.fechaPublicacion, this.semestres, this.totalFilas);
}

class AllPayload {
  final Manifest manifest;
  final List<EntradaCalendario> calendario;
  final List<Entidad> entidades;
  final List<XiiiMes> xiii;
  const AllPayload(this.manifest, this.calendario, this.entidades, this.xiii);
}

class AllResponse {
  final bool notModified;
  final String? etag;
  final AllPayload? payload;
  const AllResponse({required this.notModified, this.etag, this.payload});
}
