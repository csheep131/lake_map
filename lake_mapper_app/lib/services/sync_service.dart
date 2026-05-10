import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../models/lake.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  static const _baseUrl = 'https://arxlabs.dev/lakedb';

  SyncService._init();

  String? _databaseName;

  Future<void> setDatabaseName(String name) async {
    _databaseName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('database_name', name);
  }

  Future<void> loadDatabaseName() async {
    final prefs = await SharedPreferences.getInstance();
    _databaseName = prefs.getString('database_name');
  }

  String get databaseName => _databaseName ?? 'default';

  Future<bool> isOnline() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/health')).timeout(
        const Duration(seconds: 5),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _syncRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$_baseUrl/$databaseName$endpoint');
    
    http.Response response;
    if (method == 'GET') {
      response = await http.get(url);
    } else if (method == 'POST') {
      response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } else if (method == 'PUT') {
      response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } else if (method == 'DELETE') {
      response = await http.delete(url);
    } else {
      throw Exception('Unknown method: $method');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Sync error: ${response.statusCode} ${response.body}');
    }
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString('last_sync');
    if (timestamp == null) return null;
    return DateTime.parse(timestamp);
  }

  Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_sync', time.toIso8601String());
  }

  Future<SyncResult> syncAll() async {
    if (_databaseName == null) {
      throw Exception('Database name not set');
    }

    final lastSync = await getLastSyncTime();
    int uploaded = 0;
    int downloaded = 0;

    try {
      final localPoints = await AppDatabase.instance.getAllDepthPoints();
      final localLakes = await AppDatabase.instance.getAllLakes();

      final serverData = await _syncRequest(method: 'GET', endpoint: '/all');
      
      final serverPoints = (serverData['depth_points'] as List<dynamic>?)
          ?.map((p) => DepthPoint.fromMap(p as Map<String, dynamic>))
          .toList() ?? [];
      
      final serverLakes = (serverData['lakes'] as List<dynamic>?)
          ?.map((l) => Lake.fromMap(l as Map<String, dynamic>))
          .toList() ?? [];

      final serverPointsMap = {for (var p in serverPoints) p.id: p};
      final serverLakesMap = {for (var l in serverLakes) l.id: l};

      for (final lake in localLakes) {
        if (lake.id != null && !serverLakesMap.containsKey(lake.id)) {
          await _syncRequest(
            method: 'POST',
            endpoint: '/lakes',
            body: lake.toMap(),
          );
        }
      }

      for (final point in localPoints) {
        final serverPoint = serverPointsMap[point.id];
        if (serverPoint == null) {
          await _syncRequest(
            method: 'POST',
            endpoint: '/depth_points',
            body: point.toMap(),
          );
          uploaded++;
        } else if (lastSync != null && point.createdAt.isAfter(lastSync)) {
          await _syncRequest(
            method: 'PUT',
            endpoint: '/depth_points/${point.id}',
            body: point.toMap(),
          );
          uploaded++;
        }
      }

      final localPointsMap = {for (var p in localPoints) p.id: p};
      
      for (final serverPoint in serverPoints) {
        if (!localPointsMap.containsKey(serverPoint.id)) {
          await AppDatabase.instance.insertDepthPoint(serverPoint);
          downloaded++;
        }
      }

      final localLakesMap = {for (var l in localLakes) l.id: l};
      
      for (final serverLake in serverLakes) {
        if (!localLakesMap.containsKey(serverLake.id)) {
          await AppDatabase.instance.insertLake(serverLake);
        }
      }

      await setLastSyncTime(DateTime.now().toUtc());

      return SyncResult(uploaded: uploaded, downloaded: downloaded);
    } catch (e) {
      rethrow;
    }
  }
}

class SyncResult {
  final int uploaded;
  final int downloaded;

  SyncResult({required this.uploaded, required this.downloaded});
}