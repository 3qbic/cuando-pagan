// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CalendarioTable extends Calendario
    with TableInfo<$CalendarioTable, CalendarioData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalendarioTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anioMeta = const VerificationMeta('anio');
  @override
  late final GeneratedColumn<int> anio = GeneratedColumn<int>(
      'anio', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _semestreMeta =
      const VerificationMeta('semestre');
  @override
  late final GeneratedColumn<int> semestre = GeneratedColumn<int>(
      'semestre', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mesMeta = const VerificationMeta('mes');
  @override
  late final GeneratedColumn<String> mes = GeneratedColumn<String>(
      'mes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _mesNumMeta = const VerificationMeta('mesNum');
  @override
  late final GeneratedColumn<int> mesNum = GeneratedColumn<int>(
      'mes_num', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoriaMeta =
      const VerificationMeta('categoria');
  @override
  late final GeneratedColumn<String> categoria = GeneratedColumn<String>(
      'categoria', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quincenaMeta =
      const VerificationMeta('quincena');
  @override
  late final GeneratedColumn<int> quincena = GeneratedColumn<int>(
      'quincena', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _inicioRegistroMeta =
      const VerificationMeta('inicioRegistro');
  @override
  late final GeneratedColumn<String> inicioRegistro = GeneratedColumn<String>(
      'inicio_registro', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cierreRegistroMeta =
      const VerificationMeta('cierreRegistro');
  @override
  late final GeneratedColumn<String> cierreRegistro = GeneratedColumn<String>(
      'cierre_registro', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _retencionAchMeta =
      const VerificationMeta('retencionAch');
  @override
  late final GeneratedColumn<String> retencionAch = GeneratedColumn<String>(
      'retencion_ach', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fechaPagoMeta =
      const VerificationMeta('fechaPago');
  @override
  late final GeneratedColumn<String> fechaPago = GeneratedColumn<String>(
      'fecha_pago', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
      'estado', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _precisionMeta =
      const VerificationMeta('precision');
  @override
  late final GeneratedColumn<String> precision = GeneratedColumn<String>(
      'precision', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        anio,
        semestre,
        mes,
        mesNum,
        categoria,
        quincena,
        inicioRegistro,
        cierreRegistro,
        retencionAch,
        fechaPago,
        estado,
        precision
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calendario';
  @override
  VerificationContext validateIntegrity(Insertable<CalendarioData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anio')) {
      context.handle(
          _anioMeta, anio.isAcceptableOrUnknown(data['anio']!, _anioMeta));
    } else if (isInserting) {
      context.missing(_anioMeta);
    }
    if (data.containsKey('semestre')) {
      context.handle(_semestreMeta,
          semestre.isAcceptableOrUnknown(data['semestre']!, _semestreMeta));
    } else if (isInserting) {
      context.missing(_semestreMeta);
    }
    if (data.containsKey('mes')) {
      context.handle(
          _mesMeta, mes.isAcceptableOrUnknown(data['mes']!, _mesMeta));
    } else if (isInserting) {
      context.missing(_mesMeta);
    }
    if (data.containsKey('mes_num')) {
      context.handle(_mesNumMeta,
          mesNum.isAcceptableOrUnknown(data['mes_num']!, _mesNumMeta));
    } else if (isInserting) {
      context.missing(_mesNumMeta);
    }
    if (data.containsKey('categoria')) {
      context.handle(_categoriaMeta,
          categoria.isAcceptableOrUnknown(data['categoria']!, _categoriaMeta));
    } else if (isInserting) {
      context.missing(_categoriaMeta);
    }
    if (data.containsKey('quincena')) {
      context.handle(_quincenaMeta,
          quincena.isAcceptableOrUnknown(data['quincena']!, _quincenaMeta));
    } else if (isInserting) {
      context.missing(_quincenaMeta);
    }
    if (data.containsKey('inicio_registro')) {
      context.handle(
          _inicioRegistroMeta,
          inicioRegistro.isAcceptableOrUnknown(
              data['inicio_registro']!, _inicioRegistroMeta));
    } else if (isInserting) {
      context.missing(_inicioRegistroMeta);
    }
    if (data.containsKey('cierre_registro')) {
      context.handle(
          _cierreRegistroMeta,
          cierreRegistro.isAcceptableOrUnknown(
              data['cierre_registro']!, _cierreRegistroMeta));
    } else if (isInserting) {
      context.missing(_cierreRegistroMeta);
    }
    if (data.containsKey('retencion_ach')) {
      context.handle(
          _retencionAchMeta,
          retencionAch.isAcceptableOrUnknown(
              data['retencion_ach']!, _retencionAchMeta));
    } else if (isInserting) {
      context.missing(_retencionAchMeta);
    }
    if (data.containsKey('fecha_pago')) {
      context.handle(_fechaPagoMeta,
          fechaPago.isAcceptableOrUnknown(data['fecha_pago']!, _fechaPagoMeta));
    } else if (isInserting) {
      context.missing(_fechaPagoMeta);
    }
    if (data.containsKey('estado')) {
      context.handle(_estadoMeta,
          estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta));
    } else if (isInserting) {
      context.missing(_estadoMeta);
    }
    if (data.containsKey('precision')) {
      context.handle(_precisionMeta,
          precision.isAcceptableOrUnknown(data['precision']!, _precisionMeta));
    } else if (isInserting) {
      context.missing(_precisionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  CalendarioData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalendarioData(
      anio: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}anio'])!,
      semestre: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}semestre'])!,
      mes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mes'])!,
      mesNum: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}mes_num'])!,
      categoria: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}categoria'])!,
      quincena: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}quincena'])!,
      inicioRegistro: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}inicio_registro'])!,
      cierreRegistro: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cierre_registro'])!,
      retencionAch: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}retencion_ach'])!,
      fechaPago: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fecha_pago'])!,
      estado: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}estado'])!,
      precision: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}precision'])!,
    );
  }

  @override
  $CalendarioTable createAlias(String alias) {
    return $CalendarioTable(attachedDatabase, alias);
  }
}

class CalendarioData extends DataClass implements Insertable<CalendarioData> {
  final int anio;
  final int semestre;
  final String mes;
  final int mesNum;
  final String categoria;
  final int quincena;
  final String inicioRegistro;
  final String cierreRegistro;
  final String retencionAch;
  final String fechaPago;
  final String estado;
  final String precision;
  const CalendarioData(
      {required this.anio,
      required this.semestre,
      required this.mes,
      required this.mesNum,
      required this.categoria,
      required this.quincena,
      required this.inicioRegistro,
      required this.cierreRegistro,
      required this.retencionAch,
      required this.fechaPago,
      required this.estado,
      required this.precision});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anio'] = Variable<int>(anio);
    map['semestre'] = Variable<int>(semestre);
    map['mes'] = Variable<String>(mes);
    map['mes_num'] = Variable<int>(mesNum);
    map['categoria'] = Variable<String>(categoria);
    map['quincena'] = Variable<int>(quincena);
    map['inicio_registro'] = Variable<String>(inicioRegistro);
    map['cierre_registro'] = Variable<String>(cierreRegistro);
    map['retencion_ach'] = Variable<String>(retencionAch);
    map['fecha_pago'] = Variable<String>(fechaPago);
    map['estado'] = Variable<String>(estado);
    map['precision'] = Variable<String>(precision);
    return map;
  }

  CalendarioCompanion toCompanion(bool nullToAbsent) {
    return CalendarioCompanion(
      anio: Value(anio),
      semestre: Value(semestre),
      mes: Value(mes),
      mesNum: Value(mesNum),
      categoria: Value(categoria),
      quincena: Value(quincena),
      inicioRegistro: Value(inicioRegistro),
      cierreRegistro: Value(cierreRegistro),
      retencionAch: Value(retencionAch),
      fechaPago: Value(fechaPago),
      estado: Value(estado),
      precision: Value(precision),
    );
  }

  factory CalendarioData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalendarioData(
      anio: serializer.fromJson<int>(json['anio']),
      semestre: serializer.fromJson<int>(json['semestre']),
      mes: serializer.fromJson<String>(json['mes']),
      mesNum: serializer.fromJson<int>(json['mesNum']),
      categoria: serializer.fromJson<String>(json['categoria']),
      quincena: serializer.fromJson<int>(json['quincena']),
      inicioRegistro: serializer.fromJson<String>(json['inicioRegistro']),
      cierreRegistro: serializer.fromJson<String>(json['cierreRegistro']),
      retencionAch: serializer.fromJson<String>(json['retencionAch']),
      fechaPago: serializer.fromJson<String>(json['fechaPago']),
      estado: serializer.fromJson<String>(json['estado']),
      precision: serializer.fromJson<String>(json['precision']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anio': serializer.toJson<int>(anio),
      'semestre': serializer.toJson<int>(semestre),
      'mes': serializer.toJson<String>(mes),
      'mesNum': serializer.toJson<int>(mesNum),
      'categoria': serializer.toJson<String>(categoria),
      'quincena': serializer.toJson<int>(quincena),
      'inicioRegistro': serializer.toJson<String>(inicioRegistro),
      'cierreRegistro': serializer.toJson<String>(cierreRegistro),
      'retencionAch': serializer.toJson<String>(retencionAch),
      'fechaPago': serializer.toJson<String>(fechaPago),
      'estado': serializer.toJson<String>(estado),
      'precision': serializer.toJson<String>(precision),
    };
  }

  CalendarioData copyWith(
          {int? anio,
          int? semestre,
          String? mes,
          int? mesNum,
          String? categoria,
          int? quincena,
          String? inicioRegistro,
          String? cierreRegistro,
          String? retencionAch,
          String? fechaPago,
          String? estado,
          String? precision}) =>
      CalendarioData(
        anio: anio ?? this.anio,
        semestre: semestre ?? this.semestre,
        mes: mes ?? this.mes,
        mesNum: mesNum ?? this.mesNum,
        categoria: categoria ?? this.categoria,
        quincena: quincena ?? this.quincena,
        inicioRegistro: inicioRegistro ?? this.inicioRegistro,
        cierreRegistro: cierreRegistro ?? this.cierreRegistro,
        retencionAch: retencionAch ?? this.retencionAch,
        fechaPago: fechaPago ?? this.fechaPago,
        estado: estado ?? this.estado,
        precision: precision ?? this.precision,
      );
  CalendarioData copyWithCompanion(CalendarioCompanion data) {
    return CalendarioData(
      anio: data.anio.present ? data.anio.value : this.anio,
      semestre: data.semestre.present ? data.semestre.value : this.semestre,
      mes: data.mes.present ? data.mes.value : this.mes,
      mesNum: data.mesNum.present ? data.mesNum.value : this.mesNum,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      quincena: data.quincena.present ? data.quincena.value : this.quincena,
      inicioRegistro: data.inicioRegistro.present
          ? data.inicioRegistro.value
          : this.inicioRegistro,
      cierreRegistro: data.cierreRegistro.present
          ? data.cierreRegistro.value
          : this.cierreRegistro,
      retencionAch: data.retencionAch.present
          ? data.retencionAch.value
          : this.retencionAch,
      fechaPago: data.fechaPago.present ? data.fechaPago.value : this.fechaPago,
      estado: data.estado.present ? data.estado.value : this.estado,
      precision: data.precision.present ? data.precision.value : this.precision,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalendarioData(')
          ..write('anio: $anio, ')
          ..write('semestre: $semestre, ')
          ..write('mes: $mes, ')
          ..write('mesNum: $mesNum, ')
          ..write('categoria: $categoria, ')
          ..write('quincena: $quincena, ')
          ..write('inicioRegistro: $inicioRegistro, ')
          ..write('cierreRegistro: $cierreRegistro, ')
          ..write('retencionAch: $retencionAch, ')
          ..write('fechaPago: $fechaPago, ')
          ..write('estado: $estado, ')
          ..write('precision: $precision')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      anio,
      semestre,
      mes,
      mesNum,
      categoria,
      quincena,
      inicioRegistro,
      cierreRegistro,
      retencionAch,
      fechaPago,
      estado,
      precision);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalendarioData &&
          other.anio == this.anio &&
          other.semestre == this.semestre &&
          other.mes == this.mes &&
          other.mesNum == this.mesNum &&
          other.categoria == this.categoria &&
          other.quincena == this.quincena &&
          other.inicioRegistro == this.inicioRegistro &&
          other.cierreRegistro == this.cierreRegistro &&
          other.retencionAch == this.retencionAch &&
          other.fechaPago == this.fechaPago &&
          other.estado == this.estado &&
          other.precision == this.precision);
}

class CalendarioCompanion extends UpdateCompanion<CalendarioData> {
  final Value<int> anio;
  final Value<int> semestre;
  final Value<String> mes;
  final Value<int> mesNum;
  final Value<String> categoria;
  final Value<int> quincena;
  final Value<String> inicioRegistro;
  final Value<String> cierreRegistro;
  final Value<String> retencionAch;
  final Value<String> fechaPago;
  final Value<String> estado;
  final Value<String> precision;
  final Value<int> rowid;
  const CalendarioCompanion({
    this.anio = const Value.absent(),
    this.semestre = const Value.absent(),
    this.mes = const Value.absent(),
    this.mesNum = const Value.absent(),
    this.categoria = const Value.absent(),
    this.quincena = const Value.absent(),
    this.inicioRegistro = const Value.absent(),
    this.cierreRegistro = const Value.absent(),
    this.retencionAch = const Value.absent(),
    this.fechaPago = const Value.absent(),
    this.estado = const Value.absent(),
    this.precision = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalendarioCompanion.insert({
    required int anio,
    required int semestre,
    required String mes,
    required int mesNum,
    required String categoria,
    required int quincena,
    required String inicioRegistro,
    required String cierreRegistro,
    required String retencionAch,
    required String fechaPago,
    required String estado,
    required String precision,
    this.rowid = const Value.absent(),
  })  : anio = Value(anio),
        semestre = Value(semestre),
        mes = Value(mes),
        mesNum = Value(mesNum),
        categoria = Value(categoria),
        quincena = Value(quincena),
        inicioRegistro = Value(inicioRegistro),
        cierreRegistro = Value(cierreRegistro),
        retencionAch = Value(retencionAch),
        fechaPago = Value(fechaPago),
        estado = Value(estado),
        precision = Value(precision);
  static Insertable<CalendarioData> custom({
    Expression<int>? anio,
    Expression<int>? semestre,
    Expression<String>? mes,
    Expression<int>? mesNum,
    Expression<String>? categoria,
    Expression<int>? quincena,
    Expression<String>? inicioRegistro,
    Expression<String>? cierreRegistro,
    Expression<String>? retencionAch,
    Expression<String>? fechaPago,
    Expression<String>? estado,
    Expression<String>? precision,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (anio != null) 'anio': anio,
      if (semestre != null) 'semestre': semestre,
      if (mes != null) 'mes': mes,
      if (mesNum != null) 'mes_num': mesNum,
      if (categoria != null) 'categoria': categoria,
      if (quincena != null) 'quincena': quincena,
      if (inicioRegistro != null) 'inicio_registro': inicioRegistro,
      if (cierreRegistro != null) 'cierre_registro': cierreRegistro,
      if (retencionAch != null) 'retencion_ach': retencionAch,
      if (fechaPago != null) 'fecha_pago': fechaPago,
      if (estado != null) 'estado': estado,
      if (precision != null) 'precision': precision,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalendarioCompanion copyWith(
      {Value<int>? anio,
      Value<int>? semestre,
      Value<String>? mes,
      Value<int>? mesNum,
      Value<String>? categoria,
      Value<int>? quincena,
      Value<String>? inicioRegistro,
      Value<String>? cierreRegistro,
      Value<String>? retencionAch,
      Value<String>? fechaPago,
      Value<String>? estado,
      Value<String>? precision,
      Value<int>? rowid}) {
    return CalendarioCompanion(
      anio: anio ?? this.anio,
      semestre: semestre ?? this.semestre,
      mes: mes ?? this.mes,
      mesNum: mesNum ?? this.mesNum,
      categoria: categoria ?? this.categoria,
      quincena: quincena ?? this.quincena,
      inicioRegistro: inicioRegistro ?? this.inicioRegistro,
      cierreRegistro: cierreRegistro ?? this.cierreRegistro,
      retencionAch: retencionAch ?? this.retencionAch,
      fechaPago: fechaPago ?? this.fechaPago,
      estado: estado ?? this.estado,
      precision: precision ?? this.precision,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anio.present) {
      map['anio'] = Variable<int>(anio.value);
    }
    if (semestre.present) {
      map['semestre'] = Variable<int>(semestre.value);
    }
    if (mes.present) {
      map['mes'] = Variable<String>(mes.value);
    }
    if (mesNum.present) {
      map['mes_num'] = Variable<int>(mesNum.value);
    }
    if (categoria.present) {
      map['categoria'] = Variable<String>(categoria.value);
    }
    if (quincena.present) {
      map['quincena'] = Variable<int>(quincena.value);
    }
    if (inicioRegistro.present) {
      map['inicio_registro'] = Variable<String>(inicioRegistro.value);
    }
    if (cierreRegistro.present) {
      map['cierre_registro'] = Variable<String>(cierreRegistro.value);
    }
    if (retencionAch.present) {
      map['retencion_ach'] = Variable<String>(retencionAch.value);
    }
    if (fechaPago.present) {
      map['fecha_pago'] = Variable<String>(fechaPago.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (precision.present) {
      map['precision'] = Variable<String>(precision.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalendarioCompanion(')
          ..write('anio: $anio, ')
          ..write('semestre: $semestre, ')
          ..write('mes: $mes, ')
          ..write('mesNum: $mesNum, ')
          ..write('categoria: $categoria, ')
          ..write('quincena: $quincena, ')
          ..write('inicioRegistro: $inicioRegistro, ')
          ..write('cierreRegistro: $cierreRegistro, ')
          ..write('retencionAch: $retencionAch, ')
          ..write('fechaPago: $fechaPago, ')
          ..write('estado: $estado, ')
          ..write('precision: $precision, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GruposEntidadesTable extends GruposEntidades
    with TableInfo<$GruposEntidadesTable, GruposEntidade> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GruposEntidadesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nombreWireMeta =
      const VerificationMeta('nombreWire');
  @override
  late final GeneratedColumn<String> nombreWire = GeneratedColumn<String>(
      'nombre_wire', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _grupoMeta = const VerificationMeta('grupo');
  @override
  late final GeneratedColumn<String> grupo = GeneratedColumn<String>(
      'grupo', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [nombreWire, grupo];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'grupos_entidades';
  @override
  VerificationContext validateIntegrity(Insertable<GruposEntidade> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('nombre_wire')) {
      context.handle(
          _nombreWireMeta,
          nombreWire.isAcceptableOrUnknown(
              data['nombre_wire']!, _nombreWireMeta));
    } else if (isInserting) {
      context.missing(_nombreWireMeta);
    }
    if (data.containsKey('grupo')) {
      context.handle(
          _grupoMeta, grupo.isAcceptableOrUnknown(data['grupo']!, _grupoMeta));
    } else if (isInserting) {
      context.missing(_grupoMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  GruposEntidade map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GruposEntidade(
      nombreWire: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nombre_wire'])!,
      grupo: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}grupo'])!,
    );
  }

  @override
  $GruposEntidadesTable createAlias(String alias) {
    return $GruposEntidadesTable(attachedDatabase, alias);
  }
}

class GruposEntidade extends DataClass implements Insertable<GruposEntidade> {
  final String nombreWire;
  final String grupo;
  const GruposEntidade({required this.nombreWire, required this.grupo});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['nombre_wire'] = Variable<String>(nombreWire);
    map['grupo'] = Variable<String>(grupo);
    return map;
  }

  GruposEntidadesCompanion toCompanion(bool nullToAbsent) {
    return GruposEntidadesCompanion(
      nombreWire: Value(nombreWire),
      grupo: Value(grupo),
    );
  }

  factory GruposEntidade.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GruposEntidade(
      nombreWire: serializer.fromJson<String>(json['nombreWire']),
      grupo: serializer.fromJson<String>(json['grupo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nombreWire': serializer.toJson<String>(nombreWire),
      'grupo': serializer.toJson<String>(grupo),
    };
  }

  GruposEntidade copyWith({String? nombreWire, String? grupo}) =>
      GruposEntidade(
        nombreWire: nombreWire ?? this.nombreWire,
        grupo: grupo ?? this.grupo,
      );
  GruposEntidade copyWithCompanion(GruposEntidadesCompanion data) {
    return GruposEntidade(
      nombreWire:
          data.nombreWire.present ? data.nombreWire.value : this.nombreWire,
      grupo: data.grupo.present ? data.grupo.value : this.grupo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GruposEntidade(')
          ..write('nombreWire: $nombreWire, ')
          ..write('grupo: $grupo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(nombreWire, grupo);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GruposEntidade &&
          other.nombreWire == this.nombreWire &&
          other.grupo == this.grupo);
}

class GruposEntidadesCompanion extends UpdateCompanion<GruposEntidade> {
  final Value<String> nombreWire;
  final Value<String> grupo;
  final Value<int> rowid;
  const GruposEntidadesCompanion({
    this.nombreWire = const Value.absent(),
    this.grupo = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GruposEntidadesCompanion.insert({
    required String nombreWire,
    required String grupo,
    this.rowid = const Value.absent(),
  })  : nombreWire = Value(nombreWire),
        grupo = Value(grupo);
  static Insertable<GruposEntidade> custom({
    Expression<String>? nombreWire,
    Expression<String>? grupo,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nombreWire != null) 'nombre_wire': nombreWire,
      if (grupo != null) 'grupo': grupo,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GruposEntidadesCompanion copyWith(
      {Value<String>? nombreWire, Value<String>? grupo, Value<int>? rowid}) {
    return GruposEntidadesCompanion(
      nombreWire: nombreWire ?? this.nombreWire,
      grupo: grupo ?? this.grupo,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nombreWire.present) {
      map['nombre_wire'] = Variable<String>(nombreWire.value);
    }
    if (grupo.present) {
      map['grupo'] = Variable<String>(grupo.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GruposEntidadesCompanion(')
          ..write('nombreWire: $nombreWire, ')
          ..write('grupo: $grupo, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $XiiiMesTTable extends XiiiMesT
    with TableInfo<$XiiiMesTTable, XiiiMesTData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $XiiiMesTTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _anioMeta = const VerificationMeta('anio');
  @override
  late final GeneratedColumn<int> anio = GeneratedColumn<int>(
      'anio', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _semestreMeta =
      const VerificationMeta('semestre');
  @override
  late final GeneratedColumn<int> semestre = GeneratedColumn<int>(
      'semestre', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _mesMeta = const VerificationMeta('mes');
  @override
  late final GeneratedColumn<String> mes = GeneratedColumn<String>(
      'mes', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _fechaAproxMeta =
      const VerificationMeta('fechaAprox');
  @override
  late final GeneratedColumn<String> fechaAprox = GeneratedColumn<String>(
      'fecha_aprox', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [anio, semestre, mes, fechaAprox];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'xiii_mes_t';
  @override
  VerificationContext validateIntegrity(Insertable<XiiiMesTData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('anio')) {
      context.handle(
          _anioMeta, anio.isAcceptableOrUnknown(data['anio']!, _anioMeta));
    } else if (isInserting) {
      context.missing(_anioMeta);
    }
    if (data.containsKey('semestre')) {
      context.handle(_semestreMeta,
          semestre.isAcceptableOrUnknown(data['semestre']!, _semestreMeta));
    } else if (isInserting) {
      context.missing(_semestreMeta);
    }
    if (data.containsKey('mes')) {
      context.handle(
          _mesMeta, mes.isAcceptableOrUnknown(data['mes']!, _mesMeta));
    } else if (isInserting) {
      context.missing(_mesMeta);
    }
    if (data.containsKey('fecha_aprox')) {
      context.handle(
          _fechaAproxMeta,
          fechaAprox.isAcceptableOrUnknown(
              data['fecha_aprox']!, _fechaAproxMeta));
    } else if (isInserting) {
      context.missing(_fechaAproxMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  XiiiMesTData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return XiiiMesTData(
      anio: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}anio'])!,
      semestre: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}semestre'])!,
      mes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mes'])!,
      fechaAprox: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fecha_aprox'])!,
    );
  }

  @override
  $XiiiMesTTable createAlias(String alias) {
    return $XiiiMesTTable(attachedDatabase, alias);
  }
}

class XiiiMesTData extends DataClass implements Insertable<XiiiMesTData> {
  final int anio;
  final int semestre;
  final String mes;
  final String fechaAprox;
  const XiiiMesTData(
      {required this.anio,
      required this.semestre,
      required this.mes,
      required this.fechaAprox});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['anio'] = Variable<int>(anio);
    map['semestre'] = Variable<int>(semestre);
    map['mes'] = Variable<String>(mes);
    map['fecha_aprox'] = Variable<String>(fechaAprox);
    return map;
  }

  XiiiMesTCompanion toCompanion(bool nullToAbsent) {
    return XiiiMesTCompanion(
      anio: Value(anio),
      semestre: Value(semestre),
      mes: Value(mes),
      fechaAprox: Value(fechaAprox),
    );
  }

  factory XiiiMesTData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return XiiiMesTData(
      anio: serializer.fromJson<int>(json['anio']),
      semestre: serializer.fromJson<int>(json['semestre']),
      mes: serializer.fromJson<String>(json['mes']),
      fechaAprox: serializer.fromJson<String>(json['fechaAprox']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'anio': serializer.toJson<int>(anio),
      'semestre': serializer.toJson<int>(semestre),
      'mes': serializer.toJson<String>(mes),
      'fechaAprox': serializer.toJson<String>(fechaAprox),
    };
  }

  XiiiMesTData copyWith(
          {int? anio, int? semestre, String? mes, String? fechaAprox}) =>
      XiiiMesTData(
        anio: anio ?? this.anio,
        semestre: semestre ?? this.semestre,
        mes: mes ?? this.mes,
        fechaAprox: fechaAprox ?? this.fechaAprox,
      );
  XiiiMesTData copyWithCompanion(XiiiMesTCompanion data) {
    return XiiiMesTData(
      anio: data.anio.present ? data.anio.value : this.anio,
      semestre: data.semestre.present ? data.semestre.value : this.semestre,
      mes: data.mes.present ? data.mes.value : this.mes,
      fechaAprox:
          data.fechaAprox.present ? data.fechaAprox.value : this.fechaAprox,
    );
  }

  @override
  String toString() {
    return (StringBuffer('XiiiMesTData(')
          ..write('anio: $anio, ')
          ..write('semestre: $semestre, ')
          ..write('mes: $mes, ')
          ..write('fechaAprox: $fechaAprox')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(anio, semestre, mes, fechaAprox);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is XiiiMesTData &&
          other.anio == this.anio &&
          other.semestre == this.semestre &&
          other.mes == this.mes &&
          other.fechaAprox == this.fechaAprox);
}

class XiiiMesTCompanion extends UpdateCompanion<XiiiMesTData> {
  final Value<int> anio;
  final Value<int> semestre;
  final Value<String> mes;
  final Value<String> fechaAprox;
  final Value<int> rowid;
  const XiiiMesTCompanion({
    this.anio = const Value.absent(),
    this.semestre = const Value.absent(),
    this.mes = const Value.absent(),
    this.fechaAprox = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  XiiiMesTCompanion.insert({
    required int anio,
    required int semestre,
    required String mes,
    required String fechaAprox,
    this.rowid = const Value.absent(),
  })  : anio = Value(anio),
        semestre = Value(semestre),
        mes = Value(mes),
        fechaAprox = Value(fechaAprox);
  static Insertable<XiiiMesTData> custom({
    Expression<int>? anio,
    Expression<int>? semestre,
    Expression<String>? mes,
    Expression<String>? fechaAprox,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (anio != null) 'anio': anio,
      if (semestre != null) 'semestre': semestre,
      if (mes != null) 'mes': mes,
      if (fechaAprox != null) 'fecha_aprox': fechaAprox,
      if (rowid != null) 'rowid': rowid,
    });
  }

  XiiiMesTCompanion copyWith(
      {Value<int>? anio,
      Value<int>? semestre,
      Value<String>? mes,
      Value<String>? fechaAprox,
      Value<int>? rowid}) {
    return XiiiMesTCompanion(
      anio: anio ?? this.anio,
      semestre: semestre ?? this.semestre,
      mes: mes ?? this.mes,
      fechaAprox: fechaAprox ?? this.fechaAprox,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (anio.present) {
      map['anio'] = Variable<int>(anio.value);
    }
    if (semestre.present) {
      map['semestre'] = Variable<int>(semestre.value);
    }
    if (mes.present) {
      map['mes'] = Variable<String>(mes.value);
    }
    if (fechaAprox.present) {
      map['fecha_aprox'] = Variable<String>(fechaAprox.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('XiiiMesTCompanion(')
          ..write('anio: $anio, ')
          ..write('semestre: $semestre, ')
          ..write('mes: $mes, ')
          ..write('fechaAprox: $fechaAprox, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CalendarioTable calendario = $CalendarioTable(this);
  late final $GruposEntidadesTable gruposEntidades =
      $GruposEntidadesTable(this);
  late final $XiiiMesTTable xiiiMesT = $XiiiMesTTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [calendario, gruposEntidades, xiiiMesT];
}

typedef $$CalendarioTableCreateCompanionBuilder = CalendarioCompanion Function({
  required int anio,
  required int semestre,
  required String mes,
  required int mesNum,
  required String categoria,
  required int quincena,
  required String inicioRegistro,
  required String cierreRegistro,
  required String retencionAch,
  required String fechaPago,
  required String estado,
  required String precision,
  Value<int> rowid,
});
typedef $$CalendarioTableUpdateCompanionBuilder = CalendarioCompanion Function({
  Value<int> anio,
  Value<int> semestre,
  Value<String> mes,
  Value<int> mesNum,
  Value<String> categoria,
  Value<int> quincena,
  Value<String> inicioRegistro,
  Value<String> cierreRegistro,
  Value<String> retencionAch,
  Value<String> fechaPago,
  Value<String> estado,
  Value<String> precision,
  Value<int> rowid,
});

class $$CalendarioTableFilterComposer
    extends Composer<_$AppDatabase, $CalendarioTable> {
  $$CalendarioTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anio => $composableBuilder(
      column: $table.anio, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get semestre => $composableBuilder(
      column: $table.semestre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mes => $composableBuilder(
      column: $table.mes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get mesNum => $composableBuilder(
      column: $table.mesNum, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get categoria => $composableBuilder(
      column: $table.categoria, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get quincena => $composableBuilder(
      column: $table.quincena, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inicioRegistro => $composableBuilder(
      column: $table.inicioRegistro,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cierreRegistro => $composableBuilder(
      column: $table.cierreRegistro,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get retencionAch => $composableBuilder(
      column: $table.retencionAch, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fechaPago => $composableBuilder(
      column: $table.fechaPago, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get estado => $composableBuilder(
      column: $table.estado, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get precision => $composableBuilder(
      column: $table.precision, builder: (column) => ColumnFilters(column));
}

class $$CalendarioTableOrderingComposer
    extends Composer<_$AppDatabase, $CalendarioTable> {
  $$CalendarioTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anio => $composableBuilder(
      column: $table.anio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get semestre => $composableBuilder(
      column: $table.semestre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mes => $composableBuilder(
      column: $table.mes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get mesNum => $composableBuilder(
      column: $table.mesNum, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get categoria => $composableBuilder(
      column: $table.categoria, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get quincena => $composableBuilder(
      column: $table.quincena, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inicioRegistro => $composableBuilder(
      column: $table.inicioRegistro,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cierreRegistro => $composableBuilder(
      column: $table.cierreRegistro,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get retencionAch => $composableBuilder(
      column: $table.retencionAch,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fechaPago => $composableBuilder(
      column: $table.fechaPago, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get estado => $composableBuilder(
      column: $table.estado, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get precision => $composableBuilder(
      column: $table.precision, builder: (column) => ColumnOrderings(column));
}

class $$CalendarioTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalendarioTable> {
  $$CalendarioTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anio =>
      $composableBuilder(column: $table.anio, builder: (column) => column);

  GeneratedColumn<int> get semestre =>
      $composableBuilder(column: $table.semestre, builder: (column) => column);

  GeneratedColumn<String> get mes =>
      $composableBuilder(column: $table.mes, builder: (column) => column);

  GeneratedColumn<int> get mesNum =>
      $composableBuilder(column: $table.mesNum, builder: (column) => column);

  GeneratedColumn<String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<int> get quincena =>
      $composableBuilder(column: $table.quincena, builder: (column) => column);

  GeneratedColumn<String> get inicioRegistro => $composableBuilder(
      column: $table.inicioRegistro, builder: (column) => column);

  GeneratedColumn<String> get cierreRegistro => $composableBuilder(
      column: $table.cierreRegistro, builder: (column) => column);

  GeneratedColumn<String> get retencionAch => $composableBuilder(
      column: $table.retencionAch, builder: (column) => column);

  GeneratedColumn<String> get fechaPago =>
      $composableBuilder(column: $table.fechaPago, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<String> get precision =>
      $composableBuilder(column: $table.precision, builder: (column) => column);
}

class $$CalendarioTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CalendarioTable,
    CalendarioData,
    $$CalendarioTableFilterComposer,
    $$CalendarioTableOrderingComposer,
    $$CalendarioTableAnnotationComposer,
    $$CalendarioTableCreateCompanionBuilder,
    $$CalendarioTableUpdateCompanionBuilder,
    (
      CalendarioData,
      BaseReferences<_$AppDatabase, $CalendarioTable, CalendarioData>
    ),
    CalendarioData,
    PrefetchHooks Function()> {
  $$CalendarioTableTableManager(_$AppDatabase db, $CalendarioTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalendarioTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalendarioTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CalendarioTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> anio = const Value.absent(),
            Value<int> semestre = const Value.absent(),
            Value<String> mes = const Value.absent(),
            Value<int> mesNum = const Value.absent(),
            Value<String> categoria = const Value.absent(),
            Value<int> quincena = const Value.absent(),
            Value<String> inicioRegistro = const Value.absent(),
            Value<String> cierreRegistro = const Value.absent(),
            Value<String> retencionAch = const Value.absent(),
            Value<String> fechaPago = const Value.absent(),
            Value<String> estado = const Value.absent(),
            Value<String> precision = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarioCompanion(
            anio: anio,
            semestre: semestre,
            mes: mes,
            mesNum: mesNum,
            categoria: categoria,
            quincena: quincena,
            inicioRegistro: inicioRegistro,
            cierreRegistro: cierreRegistro,
            retencionAch: retencionAch,
            fechaPago: fechaPago,
            estado: estado,
            precision: precision,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int anio,
            required int semestre,
            required String mes,
            required int mesNum,
            required String categoria,
            required int quincena,
            required String inicioRegistro,
            required String cierreRegistro,
            required String retencionAch,
            required String fechaPago,
            required String estado,
            required String precision,
            Value<int> rowid = const Value.absent(),
          }) =>
              CalendarioCompanion.insert(
            anio: anio,
            semestre: semestre,
            mes: mes,
            mesNum: mesNum,
            categoria: categoria,
            quincena: quincena,
            inicioRegistro: inicioRegistro,
            cierreRegistro: cierreRegistro,
            retencionAch: retencionAch,
            fechaPago: fechaPago,
            estado: estado,
            precision: precision,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CalendarioTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CalendarioTable,
    CalendarioData,
    $$CalendarioTableFilterComposer,
    $$CalendarioTableOrderingComposer,
    $$CalendarioTableAnnotationComposer,
    $$CalendarioTableCreateCompanionBuilder,
    $$CalendarioTableUpdateCompanionBuilder,
    (
      CalendarioData,
      BaseReferences<_$AppDatabase, $CalendarioTable, CalendarioData>
    ),
    CalendarioData,
    PrefetchHooks Function()>;
typedef $$GruposEntidadesTableCreateCompanionBuilder = GruposEntidadesCompanion
    Function({
  required String nombreWire,
  required String grupo,
  Value<int> rowid,
});
typedef $$GruposEntidadesTableUpdateCompanionBuilder = GruposEntidadesCompanion
    Function({
  Value<String> nombreWire,
  Value<String> grupo,
  Value<int> rowid,
});

class $$GruposEntidadesTableFilterComposer
    extends Composer<_$AppDatabase, $GruposEntidadesTable> {
  $$GruposEntidadesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nombreWire => $composableBuilder(
      column: $table.nombreWire, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get grupo => $composableBuilder(
      column: $table.grupo, builder: (column) => ColumnFilters(column));
}

class $$GruposEntidadesTableOrderingComposer
    extends Composer<_$AppDatabase, $GruposEntidadesTable> {
  $$GruposEntidadesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nombreWire => $composableBuilder(
      column: $table.nombreWire, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get grupo => $composableBuilder(
      column: $table.grupo, builder: (column) => ColumnOrderings(column));
}

class $$GruposEntidadesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GruposEntidadesTable> {
  $$GruposEntidadesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nombreWire => $composableBuilder(
      column: $table.nombreWire, builder: (column) => column);

  GeneratedColumn<String> get grupo =>
      $composableBuilder(column: $table.grupo, builder: (column) => column);
}

class $$GruposEntidadesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $GruposEntidadesTable,
    GruposEntidade,
    $$GruposEntidadesTableFilterComposer,
    $$GruposEntidadesTableOrderingComposer,
    $$GruposEntidadesTableAnnotationComposer,
    $$GruposEntidadesTableCreateCompanionBuilder,
    $$GruposEntidadesTableUpdateCompanionBuilder,
    (
      GruposEntidade,
      BaseReferences<_$AppDatabase, $GruposEntidadesTable, GruposEntidade>
    ),
    GruposEntidade,
    PrefetchHooks Function()> {
  $$GruposEntidadesTableTableManager(
      _$AppDatabase db, $GruposEntidadesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GruposEntidadesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GruposEntidadesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GruposEntidadesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> nombreWire = const Value.absent(),
            Value<String> grupo = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              GruposEntidadesCompanion(
            nombreWire: nombreWire,
            grupo: grupo,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String nombreWire,
            required String grupo,
            Value<int> rowid = const Value.absent(),
          }) =>
              GruposEntidadesCompanion.insert(
            nombreWire: nombreWire,
            grupo: grupo,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$GruposEntidadesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $GruposEntidadesTable,
    GruposEntidade,
    $$GruposEntidadesTableFilterComposer,
    $$GruposEntidadesTableOrderingComposer,
    $$GruposEntidadesTableAnnotationComposer,
    $$GruposEntidadesTableCreateCompanionBuilder,
    $$GruposEntidadesTableUpdateCompanionBuilder,
    (
      GruposEntidade,
      BaseReferences<_$AppDatabase, $GruposEntidadesTable, GruposEntidade>
    ),
    GruposEntidade,
    PrefetchHooks Function()>;
typedef $$XiiiMesTTableCreateCompanionBuilder = XiiiMesTCompanion Function({
  required int anio,
  required int semestre,
  required String mes,
  required String fechaAprox,
  Value<int> rowid,
});
typedef $$XiiiMesTTableUpdateCompanionBuilder = XiiiMesTCompanion Function({
  Value<int> anio,
  Value<int> semestre,
  Value<String> mes,
  Value<String> fechaAprox,
  Value<int> rowid,
});

class $$XiiiMesTTableFilterComposer
    extends Composer<_$AppDatabase, $XiiiMesTTable> {
  $$XiiiMesTTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get anio => $composableBuilder(
      column: $table.anio, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get semestre => $composableBuilder(
      column: $table.semestre, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mes => $composableBuilder(
      column: $table.mes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fechaAprox => $composableBuilder(
      column: $table.fechaAprox, builder: (column) => ColumnFilters(column));
}

class $$XiiiMesTTableOrderingComposer
    extends Composer<_$AppDatabase, $XiiiMesTTable> {
  $$XiiiMesTTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get anio => $composableBuilder(
      column: $table.anio, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get semestre => $composableBuilder(
      column: $table.semestre, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mes => $composableBuilder(
      column: $table.mes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fechaAprox => $composableBuilder(
      column: $table.fechaAprox, builder: (column) => ColumnOrderings(column));
}

class $$XiiiMesTTableAnnotationComposer
    extends Composer<_$AppDatabase, $XiiiMesTTable> {
  $$XiiiMesTTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get anio =>
      $composableBuilder(column: $table.anio, builder: (column) => column);

  GeneratedColumn<int> get semestre =>
      $composableBuilder(column: $table.semestre, builder: (column) => column);

  GeneratedColumn<String> get mes =>
      $composableBuilder(column: $table.mes, builder: (column) => column);

  GeneratedColumn<String> get fechaAprox => $composableBuilder(
      column: $table.fechaAprox, builder: (column) => column);
}

class $$XiiiMesTTableTableManager extends RootTableManager<
    _$AppDatabase,
    $XiiiMesTTable,
    XiiiMesTData,
    $$XiiiMesTTableFilterComposer,
    $$XiiiMesTTableOrderingComposer,
    $$XiiiMesTTableAnnotationComposer,
    $$XiiiMesTTableCreateCompanionBuilder,
    $$XiiiMesTTableUpdateCompanionBuilder,
    (XiiiMesTData, BaseReferences<_$AppDatabase, $XiiiMesTTable, XiiiMesTData>),
    XiiiMesTData,
    PrefetchHooks Function()> {
  $$XiiiMesTTableTableManager(_$AppDatabase db, $XiiiMesTTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$XiiiMesTTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$XiiiMesTTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$XiiiMesTTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> anio = const Value.absent(),
            Value<int> semestre = const Value.absent(),
            Value<String> mes = const Value.absent(),
            Value<String> fechaAprox = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              XiiiMesTCompanion(
            anio: anio,
            semestre: semestre,
            mes: mes,
            fechaAprox: fechaAprox,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int anio,
            required int semestre,
            required String mes,
            required String fechaAprox,
            Value<int> rowid = const Value.absent(),
          }) =>
              XiiiMesTCompanion.insert(
            anio: anio,
            semestre: semestre,
            mes: mes,
            fechaAprox: fechaAprox,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$XiiiMesTTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $XiiiMesTTable,
    XiiiMesTData,
    $$XiiiMesTTableFilterComposer,
    $$XiiiMesTTableOrderingComposer,
    $$XiiiMesTTableAnnotationComposer,
    $$XiiiMesTTableCreateCompanionBuilder,
    $$XiiiMesTTableUpdateCompanionBuilder,
    (XiiiMesTData, BaseReferences<_$AppDatabase, $XiiiMesTTable, XiiiMesTData>),
    XiiiMesTData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CalendarioTableTableManager get calendario =>
      $$CalendarioTableTableManager(_db, _db.calendario);
  $$GruposEntidadesTableTableManager get gruposEntidades =>
      $$GruposEntidadesTableTableManager(_db, _db.gruposEntidades);
  $$XiiiMesTTableTableManager get xiiiMesT =>
      $$XiiiMesTTableTableManager(_db, _db.xiiiMesT);
}
