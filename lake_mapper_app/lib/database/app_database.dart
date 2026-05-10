import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/lake.dart';
import '../models/depth_point.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('lake_mapper.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE lakes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE depth_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lake_id INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        depth_m REAL NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        point_number INTEGER,
        FOREIGN KEY (lake_id) REFERENCES lakes (id)
      )
    ''');

    await db.execute('CREATE INDEX idx_depth_points_lake_id ON depth_points(lake_id)');
    await db.execute('CREATE INDEX idx_depth_points_point_number ON depth_points(point_number)');

    await db.insert('lakes', {
      'name': 'Wammsee',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> insertLake(Lake lake) async {
    final db = await database;
    return await db.insert('lakes', lake.toMap());
  }

  Future<List<Lake>> getAllLakes() async {
    final db = await database;
    final result = await db.query('lakes', orderBy: 'created_at DESC');
    return result.map((map) => Lake.fromMap(map)).toList();
  }

  Future<Lake?> getLakeById(int id) async {
    final db = await database;
    final result = await db.query('lakes', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return Lake.fromMap(result.first);
  }

  Future<Lake> getOrCreateWammsee() async {
    final db = await database;
    final result = await db.query('lakes', where: 'name = ?', whereArgs: ['Wammsee']);
    if (result.isNotEmpty) {
      return Lake.fromMap(result.first);
    }
    final id = await db.insert('lakes', {
      'name': 'Wammsee',
      'created_at': DateTime.now().toIso8601String(),
    });
    return Lake(id: id, name: 'Wammsee', createdAt: DateTime.now());
  }

  Future<int> insertDepthPoint(DepthPoint point) async {
    final db = await database;
    
    int pointNumber = point.pointNumber ?? await getNextPointNumber(point.lakeId);
    
    return await db.insert('depth_points', point.copyWith(pointNumber: pointNumber).toMap());
  }

  Future<int> getNextPointNumber(int lakeId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(point_number) as max_num FROM depth_points WHERE lake_id = ?',
      [lakeId],
    );
    final maxNum = result.first['max_num'] as int?;
    return (maxNum ?? 0) + 1;
  }

  Future<List<DepthPoint>> getDepthPointsForLake(int lakeId) async {
    final db = await database;
    final result = await db.query(
      'depth_points',
      where: 'lake_id = ?',
      whereArgs: [lakeId],
      orderBy: 'created_at DESC',
    );
    return result.map((map) => DepthPoint.fromMap(map)).toList();
  }

  Future<List<DepthPoint>> getAllDepthPoints() async {
    final db = await database;
    final result = await db.query('depth_points', orderBy: 'created_at DESC');
    return result.map((map) => DepthPoint.fromMap(map)).toList();
  }

  Future<int> updateDepthPoint(DepthPoint point) async {
    final db = await database;
    return await db.update(
      'depth_points',
      point.toMap(),
      where: 'id = ?',
      whereArgs: [point.id],
    );
  }

  Future<int> deleteDepthPoint(int id) async {
    final db = await database;
    return await db.delete(
      'depth_points',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}