import 'package:drift/drift.dart';

@DataClassName('LakeData')
class LakesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('DepthPointData')
class DepthPointsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get lakeId => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get depthM => real()();
  RealColumn get accuracyM => real().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get pointNumber => integer().nullable()();
}
