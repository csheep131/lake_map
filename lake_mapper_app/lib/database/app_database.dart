import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../models/lake.dart';
import '../models/depth_point.dart';
import 'tables.dart';

export 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [LakesTable, DepthPointsTable])
class AppDatabase extends _$AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();

  AppDatabase._internal() : super(driftDatabase(name: 'lake_mapper'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {},
      onUpgrade: (Migrator m, int from, int to) async {},
    );
  }

  // --- Adapters ---
  Lake _toLake(LakeData data) => Lake(
        id: data.id,
        name: data.name,
        createdAt: data.createdAt,
      );

  DepthPoint _toDepthPoint(DepthPointData data) => DepthPoint(
        id: data.id,
        lakeId: data.lakeId,
        latitude: data.latitude,
        longitude: data.longitude,
        depthM: data.depthM,
        accuracyM: data.accuracyM,
        note: data.note,
        createdAt: data.createdAt,
        pointNumber: data.pointNumber,
      );

  // --- Lakes ---
  Future<int> insertLake(Lake lake) async {
    return await into(lakesTable).insert(
      LakesTableCompanion.insert(
        name: lake.name,
        createdAt: lake.createdAt,
      ),
    );
  }

  Future<List<Lake>> getAllLakes() async {
    final data = await select(lakesTable).get();
    return data.map(_toLake).toList();
  }

  Future<Lake?> getLakeById(int id) async {
    final data = await (select(lakesTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return data != null ? _toLake(data) : null;
  }

  Future<Lake> getOrCreateWammsee() async {
    final existing = await (select(lakesTable)
          ..where((t) => t.name.equals('Wammsee')))
        .getSingleOrNull();

    if (existing != null) {
      final lake = _toLake(existing);
      await _seedTestDataIfNeeded(lake.id!);
      return lake;
    }

    final id = await into(lakesTable).insert(
      LakesTableCompanion.insert(
        name: 'Wammsee',
        createdAt: DateTime.now(),
      ),
    );

    await _seedTestDataIfNeeded(id);
    return Lake(id: id, name: 'Wammsee', createdAt: DateTime.now());
  }

  Future<void> _seedTestDataIfNeeded(int lakeId) async {
    final count = await (select(depthPointsTable)
          ..where((t) => t.lakeId.equals(lakeId)))
        .get();
    if (count.isNotEmpty) return;

    final now = DateTime.now();
    await into(depthPointsTable).insert(
      DepthPointsTableCompanion.insert(
        lakeId: lakeId,
        latitude: 49.34750,
        longitude: 8.44750,
        depthM: 3.50,
        note: const Value('Testpunkt Nord – Schilfzone'),
        createdAt: now.subtract(const Duration(minutes: 5)),
        pointNumber: const Value(1),
      ),
    );
    await into(depthPointsTable).insert(
      DepthPointsTableCompanion.insert(
        lakeId: lakeId,
        latitude: 49.34620,
        longitude: 8.44620,
        depthM: 6.20,
        note: const Value('Testpunkt Süd – Tiefenbereich'),
        createdAt: now.subtract(const Duration(minutes: 2)),
        pointNumber: const Value(2),
      ),
    );
  }

  // --- Depth Points ---
  Future<int> insertDepthPoint(DepthPoint point) async {
    final pointNumber = point.pointNumber ?? await getNextPointNumber(point.lakeId);

    return await into(depthPointsTable).insert(
      DepthPointsTableCompanion.insert(
        lakeId: point.lakeId,
        latitude: point.latitude,
        longitude: point.longitude,
        depthM: point.depthM,
        accuracyM: Value(point.accuracyM),
        note: Value(point.note),
        createdAt: point.createdAt,
        pointNumber: Value(pointNumber),
      ),
    );
  }

  Future<List<DepthPoint>> getDepthPointsForLake(int lakeId) async {
    final data = await (select(depthPointsTable)
          ..where((t) => t.lakeId.equals(lakeId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    return data.map(_toDepthPoint).toList();
  }

  Future<List<DepthPoint>> getAllDepthPoints() async {
    final data = await (select(depthPointsTable)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
    return data.map(_toDepthPoint).toList();
  }

  Future<int> updateDepthPoint(DepthPoint point) async {
    return await (update(depthPointsTable)
          ..where((t) => t.id.equals(point.id!)))
        .write(
          DepthPointsTableCompanion(
            lakeId: Value(point.lakeId),
            latitude: Value(point.latitude),
            longitude: Value(point.longitude),
            depthM: Value(point.depthM),
            accuracyM: Value(point.accuracyM),
            note: Value(point.note),
            createdAt: Value(point.createdAt),
            pointNumber: Value(point.pointNumber),
          ),
        );
  }

  Future<int> deleteDepthPoint(int id) async {
    return await (delete(depthPointsTable)..where((t) => t.id.equals(id))).go();
  }

  Future<int> getNextPointNumber(int lakeId) async {
    final query = selectOnly(depthPointsTable)
      ..addColumns([depthPointsTable.pointNumber.max()])
      ..where(depthPointsTable.lakeId.equals(lakeId));
    final row = await query.getSingle();
    final maxNum = row.read(depthPointsTable.pointNumber.max());
    return (maxNum ?? 0) + 1;
  }

  @override
  Future<void> close() async {
    await super.close();
  }
}
