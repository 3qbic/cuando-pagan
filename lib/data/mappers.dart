import '../domain/entities/categoria.dart';
import '../domain/entities/entidad.dart';
import '../domain/entities/entrada_calendario.dart';
import '../domain/entities/estado_fecha.dart';
import '../domain/entities/manifest.dart';
import '../domain/entities/xiii_mes.dart';

EntradaCalendario entradaFromJson(Map<String, dynamic> j) => EntradaCalendario(
      anio: j['anio'] as int, semestre: j['semestre'] as int,
      mes: j['mes'] as String, mesNum: j['mes_num'] as int,
      categoria: Categoria.fromWire(j['categoria'] as String),
      quincena: j['quincena'] as int,
      inicioRegistro: (j['inicio_registro'] ?? '') as String,
      cierreRegistro: (j['cierre_registro'] ?? '') as String,
      retencionAch: (j['retencion_ach'] ?? '') as String,
      fechaPago: j['fecha_pago'] as String,
      estado: EstadoFecha.fromWire((j['estado'] ?? 'publicada') as String),
      precision: Precision.fromWire((j['precision'] ?? 'exacta') as String),
    );

XiiiMes xiiiFromJson(Map<String, dynamic> j) => XiiiMes(
      anio: j['anio'] as int, semestre: j['semestre'] as int,
      mes: j['mes'] as String, fechaAprox: j['fecha_aprox'] as String,
    );

Manifest manifestFromJson(Map<String, dynamic> j) => Manifest(
      dataVersion: j['data_version'] as int,
      fechaPublicacion: j['fecha_publicacion'] as String,
      semestres: (j['semestres'] as List).cast<String>(),
      fuente: (j['fuente'] ?? '') as String,
      totalFilas: (j['total_filas'] ?? 0) as int,
      conteo: ((j['conteo'] ?? {}) as Map).map((k, v) => MapEntry(k as String, v as int)),
    );

/// Mapa nombreWire -> siglas (del asset). DRY: única fuente de siglas.
Map<String, List<String>> cargarSiglas(Map<String, dynamic> j) =>
    j.map((k, v) => MapEntry(k, (v as List).cast<String>()));

/// Aplica tildes/expansión "Min."->"Ministerio de" para el display (§0.1-B9).
String displayEntidad(String nombreWire) {
  var d = nombreWire.replaceFirst(RegExp(r'^Min\.\s*de\s+'), 'Ministerio de ');
  const tildes = {
    'Educacion': 'Educación', 'Economia': 'Economía', 'Obras Publicas': 'Obras Públicas',
    'Organo Judicial': 'Órgano Judicial', 'Contraloria': 'Contraloría',
    'Procuraduria': 'Procuraduría', 'Administracion': 'Administración',
    'Seguridad Publica': 'Seguridad Pública', 'Region': 'Región',
    'Nacion': 'Nación', 'Fiscalia': 'Fiscalía', 'Defensoria': 'Defensoría',
    'Republica': 'República', 'Admon.': 'Administración',
  };
  // Reemplazo por "palabra" (con fronteras): evita que "Nacion"->"Nación" dañe
  // "Nacional"->"Naciónal" o "Region"->"Regional". No sigue letra a cada lado.
  tildes.forEach((k, v) =>
      d = d.replaceAll(RegExp('(?<![A-Za-zÀ-ÿ])${RegExp.escape(k)}(?![A-Za-zÀ-ÿ])'), v));
  return d;
}

List<Entidad> construirEntidades(List<dynamic> grupos, Map<String, List<String>> siglas) =>
    grupos.map((g) {
      final m = g as Map<String, dynamic>;
      final nombre = m['entidad'] as String;
      return Entidad(
        nombreWire: nombre, display: displayEntidad(nombre),
        grupo: Categoria.fromWire(m['grupo'] as String),
        siglas: siglas[nombre] ?? const [],
      );
    }).toList();
