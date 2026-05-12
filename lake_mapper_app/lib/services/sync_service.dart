import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../models/lake.dart';

class SyncService {
  static final SyncService instance = SyncService._init();
  static const _baseUrl = 'https://wammsee.arxlabs.dev';

  SyncService._init();

  String? _databaseName;
  String? _authToken;

  Future<void> setDatabaseName(String name) async {
    _databaseName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('database_name', name);
  }

  Future<void> setAuthToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> loadDatabaseName() async {
    final prefs = await SharedPreferences.getInstance();
    _databaseName = prefs.getString('database_name');
    _authToken = prefs.getString('auth_token');
  }

  String get databaseName => _databaseName ?? 'wammsee';
  bool get hasToken => _authToken != null && _authToken!.isNotEmpty;

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
    final url = Uri.parse('$_baseUrl$endpoint');

    // Header mit Auth
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    http.Response response;
    if (method == 'GET') {
      response = await http.get(url, headers: headers);
    } else if (method == 'POST') {
      response = await http.post(url, headers: headers, body: jsonEncode(body));
    } else if (method == 'PUT') {
      response = await http.put(url, headers: headers, body: jsonEncode(body));
    } else if (method == 'DELETE') {
      response = await http.delete(url, headers: headers);
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

  Future<List<Map<String, dynamic>>> _getPendingPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pending_sync') ?? [];
    return pending.map((json) => jsonDecode(json) as Map<String, dynamic>).toList();
  }

  Future<void> _addPendingPoint(DepthPoint point) async {
    final pending = await _getPendingPoints();
    pending.add(point.toMap());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pending_sync', pending.map((p) => jsonEncode(p)).toList());
  }

  Future<void> _removePendingPoint(int pointId) async {
    final pending = await _getPendingPoints();
    pending.removeWhere((p) => p['id'] == pointId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pending_sync', pending.map((p) => jsonEncode(p)).toList());
  }

  Future<SyncResult> syncAll() async {
    int uploaded = 0;
    int downloaded = 0;

    final pendingPoints = await _getPendingPoints();
    for (final pending in pendingPoints) {
      try {
        final result = await _syncRequest(method: 'POST', endpoint: '/depths', body: pending);
        if (result['id'] != null) {
          await _removePendingPoint(pending['id'] as int);
          uploaded++;
        }
      } catch (e) {
        // Punkt bleibt in der Queue für den nächsten Sync
      }
    }

    final localPoints = await AppDatabase.instance.getAllDepthPoints();
    final serverData = await _syncRequest(method: 'GET', endpoint: '/data');

    final serverPoints = (serverData['depths'] as List<dynamic>?)
        ?.map((p) => DepthPoint.fromServerMap(p as Map<String, dynamic>))
        .toList() ?? [];

    final serverPointsMap = <int, DepthPoint>{};
    for (final p in serverPoints) {
      if (p.id != null) serverPointsMap[p.id!] = p;
    }

    final localPointsMap = <int, DepthPoint>{};
    for (final p in localPoints) {
      if (p.id != null) localPointsMap[p.id!] = p;
    }

    for (final point in localPoints) {
      if (point.id == null) continue;
      if (serverPointsMap.containsKey(point.id)) continue;

      try {
        final payload = {
          'lake_id': point.lakeId,
          'depth_m': point.depth,
          'latitude': point.latitude,
          'longitude': point.longitude,
          'accuracy_m': point.accuracyM,
          'note': point.note,
        };
        await _syncRequest(method: 'POST', endpoint: '/depths', body: payload);
        uploaded++;
      } catch (e) {
        await _addPendingPoint(point);
      }
    }

    for (final serverPoint in serverPoints) {
      if (serverPoint.id == null) continue;
      if (!localPointsMap.containsKey(serverPoint.id)) {
        await AppDatabase.instance.insertDepthPoint(serverPoint);
        downloaded++;
      }
    }

    await setLastSyncTime(DateTime.now().toUtc());
    return SyncResult(uploaded: uploaded, downloaded: downloaded);
  }
}

class SyncResult {
  final int uploaded;
  final int downloaded;
  SyncResult({required this.uploaded, required this.downloaded});
}