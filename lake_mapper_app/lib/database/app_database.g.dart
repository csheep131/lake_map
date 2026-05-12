// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LakesTableTable extends LakesTable
    with TableInfo<$LakesTableTable, LakeData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LakesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lakes_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<LakeData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LakeData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LakeData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $LakesTableTable createAlias(String alias) {
    return $LakesTableTable(attachedDatabase, alias);
  }
}

class LakeData extends DataClass implements Insertable<LakeData> {
  final int id;
  final String name;
  final DateTime createdAt;
  const LakeData({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LakesTableCompanion toCompanion(bool nullToAbsent) {
    return LakesTableCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory LakeData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LakeData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LakeData copyWith({int? id, String? name, DateTime? createdAt}) => LakeData(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
  );
  LakeData copyWithCompanion(LakesTableCompanion data) {
    return LakeData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LakeData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LakeData &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class LakesTableCompanion extends UpdateCompanion<LakeData> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const LakesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LakesTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<LakeData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LakesTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return LakesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LakesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $DepthPointsTableTable extends DepthPointsTable
    with TableInfo<$DepthPointsTableTable, DepthPointData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DepthPointsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lakeIdMeta = const VerificationMeta('lakeId');
  @override
  late final GeneratedColumn<int> lakeId = GeneratedColumn<int>(
    'lake_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _depthMMeta = const VerificationMeta('depthM');
  @override
  late final GeneratedColumn<double> depthM = GeneratedColumn<double>(
    'depth_m',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMMeta = const VerificationMeta(
    'accuracyM',
  );
  @override
  late final GeneratedColumn<double> accuracyM = GeneratedColumn<double>(
    'accuracy_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pointNumberMeta = const VerificationMeta(
    'pointNumber',
  );
  @override
  late final GeneratedColumn<int> pointNumber = GeneratedColumn<int>(
    'point_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lakeId,
    latitude,
    longitude,
    depthM,
    accuracyM,
    note,
    createdAt,
    pointNumber,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'depth_points_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<DepthPointData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lake_id')) {
      context.handle(
        _lakeIdMeta,
        lakeId.isAcceptableOrUnknown(data['lake_id']!, _lakeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lakeIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('depth_m')) {
      context.handle(
        _depthMMeta,
        depthM.isAcceptableOrUnknown(data['depth_m']!, _depthMMeta),
      );
    } else if (isInserting) {
      context.missing(_depthMMeta);
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(
        _accuracyMMeta,
        accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('point_number')) {
      context.handle(
        _pointNumberMeta,
        pointNumber.isAcceptableOrUnknown(
          data['point_number']!,
          _pointNumberMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DepthPointData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DepthPointData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lakeId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lake_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      depthM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}depth_m'],
      )!,
      accuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy_m'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      pointNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}point_number'],
      ),
    );
  }

  @override
  $DepthPointsTableTable createAlias(String alias) {
    return $DepthPointsTableTable(attachedDatabase, alias);
  }
}

class DepthPointData extends DataClass implements Insertable<DepthPointData> {
  final int id;
  final int lakeId;
  final double latitude;
  final double longitude;
  final double depthM;
  final double? accuracyM;
  final String? note;
  final DateTime createdAt;
  final int? pointNumber;
  const DepthPointData({
    required this.id,
    required this.lakeId,
    required this.latitude,
    required this.longitude,
    required this.depthM,
    this.accuracyM,
    this.note,
    required this.createdAt,
    this.pointNumber,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lake_id'] = Variable<int>(lakeId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['depth_m'] = Variable<double>(depthM);
    if (!nullToAbsent || accuracyM != null) {
      map['accuracy_m'] = Variable<double>(accuracyM);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || pointNumber != null) {
      map['point_number'] = Variable<int>(pointNumber);
    }
    return map;
  }

  DepthPointsTableCompanion toCompanion(bool nullToAbsent) {
    return DepthPointsTableCompanion(
      id: Value(id),
      lakeId: Value(lakeId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      depthM: Value(depthM),
      accuracyM: accuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyM),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      pointNumber: pointNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pointNumber),
    );
  }

  factory DepthPointData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DepthPointData(
      id: serializer.fromJson<int>(json['id']),
      lakeId: serializer.fromJson<int>(json['lakeId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      depthM: serializer.fromJson<double>(json['depthM']),
      accuracyM: serializer.fromJson<double?>(json['accuracyM']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      pointNumber: serializer.fromJson<int?>(json['pointNumber']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lakeId': serializer.toJson<int>(lakeId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'depthM': serializer.toJson<double>(depthM),
      'accuracyM': serializer.toJson<double?>(accuracyM),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'pointNumber': serializer.toJson<int?>(pointNumber),
    };
  }

  DepthPointData copyWith({
    int? id,
    int? lakeId,
    double? latitude,
    double? longitude,
    double? depthM,
    Value<double?> accuracyM = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    Value<int?> pointNumber = const Value.absent(),
  }) => DepthPointData(
    id: id ?? this.id,
    lakeId: lakeId ?? this.lakeId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    depthM: depthM ?? this.depthM,
    accuracyM: accuracyM.present ? accuracyM.value : this.accuracyM,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    pointNumber: pointNumber.present ? pointNumber.value : this.pointNumber,
  );
  DepthPointData copyWithCompanion(DepthPointsTableCompanion data) {
    return DepthPointData(
      id: data.id.present ? data.id.value : this.id,
      lakeId: data.lakeId.present ? data.lakeId.value : this.lakeId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      depthM: data.depthM.present ? data.depthM.value : this.depthM,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      pointNumber: data.pointNumber.present
          ? data.pointNumber.value
          : this.pointNumber,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DepthPointData(')
          ..write('id: $id, ')
          ..write('lakeId: $lakeId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('depthM: $depthM, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('pointNumber: $pointNumber')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lakeId,
    latitude,
    longitude,
    depthM,
    accuracyM,
    note,
    createdAt,
    pointNumber,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DepthPointData &&
          other.id == this.id &&
          other.lakeId == this.lakeId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.depthM == this.depthM &&
          other.accuracyM == this.accuracyM &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.pointNumber == this.pointNumber);
}

class DepthPointsTableCompanion extends UpdateCompanion<DepthPointData> {
  final Value<int> id;
  final Value<int> lakeId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double> depthM;
  final Value<double?> accuracyM;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<int?> pointNumber;
  const DepthPointsTableCompanion({
    this.id = const Value.absent(),
    this.lakeId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.depthM = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.pointNumber = const Value.absent(),
  });
  DepthPointsTableCompanion.insert({
    this.id = const Value.absent(),
    required int lakeId,
    required double latitude,
    required double longitude,
    required double depthM,
    this.accuracyM = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.pointNumber = const Value.absent(),
  }) : lakeId = Value(lakeId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       depthM = Value(depthM),
       createdAt = Value(createdAt);
  static Insertable<DepthPointData> custom({
    Expression<int>? id,
    Expression<int>? lakeId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? depthM,
    Expression<double>? accuracyM,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<int>? pointNumber,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lakeId != null) 'lake_id': lakeId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (depthM != null) 'depth_m': depthM,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (pointNumber != null) 'point_number': pointNumber,
    });
  }

  DepthPointsTableCompanion copyWith({
    Value<int>? id,
    Value<int>? lakeId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double>? depthM,
    Value<double?>? accuracyM,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<int?>? pointNumber,
  }) {
    return DepthPointsTableCompanion(
      id: id ?? this.id,
      lakeId: lakeId ?? this.lakeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      depthM: depthM ?? this.depthM,
      accuracyM: accuracyM ?? this.accuracyM,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      pointNumber: pointNumber ?? this.pointNumber,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lakeId.present) {
      map['lake_id'] = Variable<int>(lakeId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (depthM.present) {
      map['depth_m'] = Variable<double>(depthM.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<double>(accuracyM.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (pointNumber.present) {
      map['point_number'] = Variable<int>(pointNumber.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DepthPointsTableCompanion(')
          ..write('id: $id, ')
          ..write('lakeId: $lakeId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('depthM: $depthM, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('pointNumber: $pointNumber')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LakesTableTable lakesTable = $LakesTableTable(this);
  late final $DepthPointsTableTable depthPointsTable = $DepthPointsTableTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lakesTable,
    depthPointsTable,
  ];
}

typedef $$LakesTableTableCreateCompanionBuilder =
    LakesTableCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
    });
typedef $$LakesTableTableUpdateCompanionBuilder =
    LakesTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

class $$LakesTableTableFilterComposer
    extends Composer<_$AppDatabase, $LakesTableTable> {
  $$LakesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LakesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LakesTableTable> {
  $$LakesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LakesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LakesTableTable> {
  $$LakesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LakesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LakesTableTable,
          LakeData,
          $$LakesTableTableFilterComposer,
          $$LakesTableTableOrderingComposer,
          $$LakesTableTableAnnotationComposer,
          $$LakesTableTableCreateCompanionBuilder,
          $$LakesTableTableUpdateCompanionBuilder,
          (LakeData, BaseReferences<_$AppDatabase, $LakesTableTable, LakeData>),
          LakeData,
          PrefetchHooks Function()
        > {
  $$LakesTableTableTableManager(_$AppDatabase db, $LakesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LakesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LakesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LakesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) =>
                  LakesTableCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => LakesTableCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LakesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LakesTableTable,
      LakeData,
      $$LakesTableTableFilterComposer,
      $$LakesTableTableOrderingComposer,
      $$LakesTableTableAnnotationComposer,
      $$LakesTableTableCreateCompanionBuilder,
      $$LakesTableTableUpdateCompanionBuilder,
      (LakeData, BaseReferences<_$AppDatabase, $LakesTableTable, LakeData>),
      LakeData,
      PrefetchHooks Function()
    >;
typedef $$DepthPointsTableTableCreateCompanionBuilder =
    DepthPointsTableCompanion Function({
      Value<int> id,
      required int lakeId,
      required double latitude,
      required double longitude,
      required double depthM,
      Value<double?> accuracyM,
      Value<String?> note,
      required DateTime createdAt,
      Value<int?> pointNumber,
    });
typedef $$DepthPointsTableTableUpdateCompanionBuilder =
    DepthPointsTableCompanion Function({
      Value<int> id,
      Value<int> lakeId,
      Value<double> latitude,
      Value<double> longitude,
      Value<double> depthM,
      Value<double?> accuracyM,
      Value<String?> note,
      Value<DateTime> createdAt,
      Value<int?> pointNumber,
    });

class $$DepthPointsTableTableFilterComposer
    extends Composer<_$AppDatabase, $DepthPointsTableTable> {
  $$DepthPointsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lakeId => $composableBuilder(
    column: $table.lakeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get depthM => $composableBuilder(
    column: $table.depthM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pointNumber => $composableBuilder(
    column: $table.pointNumber,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DepthPointsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DepthPointsTableTable> {
  $$DepthPointsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lakeId => $composableBuilder(
    column: $table.lakeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get depthM => $composableBuilder(
    column: $table.depthM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pointNumber => $composableBuilder(
    column: $table.pointNumber,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DepthPointsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DepthPointsTableTable> {
  $$DepthPointsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lakeId =>
      $composableBuilder(column: $table.lakeId, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get depthM =>
      $composableBuilder(column: $table.depthM, builder: (column) => column);

  GeneratedColumn<double> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get pointNumber => $composableBuilder(
    column: $table.pointNumber,
    builder: (column) => column,
  );
}

class $$DepthPointsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DepthPointsTableTable,
          DepthPointData,
          $$DepthPointsTableTableFilterComposer,
          $$DepthPointsTableTableOrderingComposer,
          $$DepthPointsTableTableAnnotationComposer,
          $$DepthPointsTableTableCreateCompanionBuilder,
          $$DepthPointsTableTableUpdateCompanionBuilder,
          (
            DepthPointData,
            BaseReferences<
              _$AppDatabase,
              $DepthPointsTableTable,
              DepthPointData
            >,
          ),
          DepthPointData,
          PrefetchHooks Function()
        > {
  $$DepthPointsTableTableTableManager(
    _$AppDatabase db,
    $DepthPointsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DepthPointsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DepthPointsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DepthPointsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lakeId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double> depthM = const Value.absent(),
                Value<double?> accuracyM = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> pointNumber = const Value.absent(),
              }) => DepthPointsTableCompanion(
                id: id,
                lakeId: lakeId,
                latitude: latitude,
                longitude: longitude,
                depthM: depthM,
                accuracyM: accuracyM,
                note: note,
                createdAt: createdAt,
                pointNumber: pointNumber,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lakeId,
                required double latitude,
                required double longitude,
                required double depthM,
                Value<double?> accuracyM = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<int?> pointNumber = const Value.absent(),
              }) => DepthPointsTableCompanion.insert(
                id: id,
                lakeId: lakeId,
                latitude: latitude,
                longitude: longitude,
                depthM: depthM,
                accuracyM: accuracyM,
                note: note,
                createdAt: createdAt,
                pointNumber: pointNumber,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DepthPointsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DepthPointsTableTable,
      DepthPointData,
      $$DepthPointsTableTableFilterComposer,
      $$DepthPointsTableTableOrderingComposer,
      $$DepthPointsTableTableAnnotationComposer,
      $$DepthPointsTableTableCreateCompanionBuilder,
      $$DepthPointsTableTableUpdateCompanionBuilder,
      (
        DepthPointData,
        BaseReferences<_$AppDatabase, $DepthPointsTableTable, DepthPointData>,
      ),
      DepthPointData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LakesTableTableTableManager get lakesTable =>
      $$LakesTableTableTableManager(_db, _db.lakesTable);
  $$DepthPointsTableTableTableManager get depthPointsTable =>
      $$DepthPointsTableTableTableManager(_db, _db.depthPointsTable);
}
