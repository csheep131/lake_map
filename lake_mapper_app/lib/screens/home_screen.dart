import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../services/sync_service.dart';
import 'map_screen.dart';
import 'export_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _depthController = TextEditingController();
  final _noteController = TextEditingController();
  
  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSyncing = false;
  bool _isOnline = false;
  String? _syncStatus;
  int? _lastPointNumber;
  List<DepthPoint> _recentPoints = [];

  static const _accuracyWarningThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await SyncService.instance.loadDatabaseName();
    await _loadRecentPoints();
    _loadCurrentPosition();
    _checkOnlineStatus();
  }

  Future<void> _loadRecentPoints() async {
    final points = await AppDatabase.instance.getAllDepthPoints();
    if (points.isNotEmpty) {
      _lastPointNumber = points.first.pointNumber;
    }
    _recentPoints = points.take(5).toList();
  }

  Future<void> _checkOnlineStatus() async {
    final online = await SyncService.instance.isOnline();
    setState(() => _isOnline = online);
  }

  Future<void> _sync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Synchronisiere...';
    });

    try {
      final result = await SyncService.instance.syncAll();
      setState(() {
        _syncStatus = 'Hochgeladen: ${result.uploaded}, Heruntergeladen: ${result.downloaded}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_syncStatus!)),
        );
      }
    } catch (e) {
      setState(() {
        _syncStatus = 'Sync-Fehler: $e';
      });
    } finally {
      setState(() => _isSyncing = false);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _syncStatus = null);
    }
  }

  @override
  void dispose() {
    _depthController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPosition() async {
    setState(() { _errorMessage = null; });

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      setState(() => _errorMessage = 'GPS konnte nicht ermittelt werden');
    }
  }

  Future<void> _savePoint() async {
    final depthText = _depthController.text.trim();
    if (depthText.isEmpty) {
      _showError('Bitte Tiefe eingeben');
      return;
    }

    final depth = double.tryParse(depthText.replaceAll(',', '.'));
    if (depth == null || depth <= 0) {
      _showError('Bitte gültige Tiefe eingeben (> 0)');
      return;
    }

    if (_currentPosition == null) {
      _showError('Keine GPS-Position verfügbar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final point = DepthPoint(
        lakeId: 1,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        depthM: depth,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      await AppDatabase.instance.insertDepthPoint(point);

      _depthController.clear();
      _noteController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Messpunkt #${_lastPointNumber} gespeichert')),
        );
        await _loadRecentPoints();
        _loadCurrentPosition();
      }
    } catch (e) {
      _showError('Fehler beim Speichern: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getDepthColor(double depth) {
    if (depth < 2) return Colors.green[300]!;
    if (depth < 4) return Colors.green[600]!;
    if (depth < 6) return Colors.blue[300]!;
    if (depth < 8) return Colors.blue[600]!;
    return Colors.blue[900]!;
  }

  Future<void> _duplicateLastPoint() async {
    if (_lastPointNumber == null || _currentPosition == null) return;

    final lastPoint = _recentPoints.firstWhere((p) => p.pointNumber == _lastPointNumber);
    
    setState(() => _isLoading = true);

    try {
      final point = DepthPoint(
        lakeId: lastPoint.lakeId,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        depthM: lastPoint.depthM,
        note: lastPoint.note,
        createdAt: DateTime.now(),
      );

      await AppDatabase.instance.insertDepthPoint(point);
      _depthController.text = lastPoint.depthM.toString();
      _noteController.text = lastPoint.note ?? '';

      if (mounted) {
        await _loadRecentPoints();
        _loadCurrentPosition();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tiefe übernommen - GPS aktualisiert')),
        );
      }
    } catch (e) {
      _showError('Fehler: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lake Mapper${SyncService.instance.databaseName != 'default' ? ' • ${SyncService.instance.databaseName}' : ''}'),
        actions: [
          IconButton(
            icon: _isSyncing 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _isSyncing ? null : _sync,
            tooltip: _isOnline ? 'Sync' : 'Offline',
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExportScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_syncStatus != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.blue.shade100,
              child: Text(_syncStatus!, style: const TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Aktuelle Position', style: TextStyle(fontWeight: FontWeight.bold)),
                              if (_lastPointNumber != null)
                                Text('#${_lastPointNumber}', style: TextStyle(color: Colors.grey.shade600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_currentPosition != null) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
                                      Text('Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Genauigkeit: ±${_currentPosition!.accuracy.toStringAsFixed(1)} m'),
                                    if (_currentPosition!.accuracy > _accuracyWarningThreshold)
                                      const Text('⚠️ Ungenau', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                  ],
                                ),
                              ],
                            ),
                          ] else if (_errorMessage != null) ...[
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _loadCurrentPosition, child: const Text('Erneut versuchen')),
                          ] else
                            const CircularProgressIndicator(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _depthController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tiefe (m)', border: OutlineInputBorder(), suffixText: 'm'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Notiz (optional)', border: OutlineInputBorder(), hintText: 'z.B. Kante, Schilf'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _savePoint,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                          child: _isLoading ? const CircularProgressIndicator() : const Text('Messpunkt speichern'),
                        ),
                      ),
                      if (_lastPointNumber != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _isLoading ? null : _duplicateLastPoint,
                          icon: const Icon(Icons.content_copy),
                          tooltip: 'Letzten Punkt duplizieren',
                        ),
                      ],
                    ],
                  ),
                  if (_recentPoints.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Letzte Punkte', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._recentPoints.map((p) => Card(
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: _getDepthColor(p.depthM),
                          child: Text(
                            '${p.pointNumber}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        title: Text('${p.depthM.toStringAsFixed(2)} m${p.note != null ? ' • ${p.note}' : ''}'),
                        subtitle: Text(
                          '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}