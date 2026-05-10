import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../data/wammsee_polygon.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<DepthPoint> _points = [];
  Position? _currentPosition;
  bool _isLoading = true;

  static const _wammseeCenter = LatLng(49.346970, 8.446897);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final points = await AppDatabase.instance.getAllDepthPoints();
      Position? position;

      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
      } catch (e) {
        position = null;
      }

      setState(() {
        _points = points;
        _currentPosition = position;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getDepthColor(double depth) {
    if (depth < 2) return Colors.green[300]!;
    if (depth < 4) return Colors.green[600]!;
    if (depth < 6) return Colors.blue[300]!;
    if (depth < 8) return Colors.blue[600]!;
    return Colors.blue[900]!;
  }

  void _onMapTap(TapPosition tapPosition, LatLng latlng) {
    _showSaveDepthDialog(latlng);
  }

  Future<void> _showSaveDepthDialog(LatLng position) async {
    final depthController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Messpunkt speichern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Position: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: depthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tiefe',
                suffixText: 'm',
                hintText: 'z.B. 3.5',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Notiz (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              final depth = double.tryParse(depthController.text.replaceAll(',', '.'));
              if (depth == null || depth <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bitte eine gültige Tiefe > 0 eingeben')),
                );
                return;
              }
              Navigator.pop(context, {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'depthM': depth,
                'note': noteController.text.isEmpty ? null : noteController.text,
              });
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != null) {
      final lake = await AppDatabase.instance.getOrCreateWammsee();
      final point = DepthPoint(
        lakeId: lake.id!,
        latitude: result['latitude'],
        longitude: result['longitude'],
        depthM: result['depthM'],
        note: result['note'],
        createdAt: DateTime.now(),
      );
      await AppDatabase.instance.insertDepthPoint(point);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messpunkt gespeichert')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wammsee • ${_points.length} Punkte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showLegend,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _points.isNotEmpty
                        ? LatLng(_points.first.latitude, _points.first.longitude)
                        : _wammseeCenter,
                    initialZoom: 15,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'de.tom.wammsee_mapper',
                    ),
                    PolygonLayer(
                      polygons: [
                        Polygon(
                          points: wammseePolygon,
                          color: Colors.blue.withValues(alpha: 0.2),
                          borderStrokeWidth: 2,
                          borderColor: Colors.blue,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        ..._points.map((point) => Marker(
                              point: LatLng(point.latitude, point.longitude),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showPointInfo(point),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getDepthColor(point.depthM),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${point.pointNumber ?? "?"}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )),
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            width: 24,
                            height: 24,
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.red,
                              size: 24,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'gps',
                        onPressed: _saveCurrentLocation,
                        child: const Icon(Icons.my_location),
                      ),
                      FloatingActionButton.small(
                        heroTag: 'center',
                        onPressed: _centerOnWammsee,
                        child: const Icon(Icons.center_focus_strong),
                      ),
                      FloatingActionButton.small(
                        heroTag: 'add',
                        onPressed: () => _showSaveDepthDialog(_wammseeCenter),
                        child: const Icon(Icons.add_location),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showPointInfo(DepthPoint point) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('#${point.pointNumber ?? "?"} - ${point.depthM.toStringAsFixed(2)} m'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Position: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
            Text('Zeit: ${dateFormat.format(point.createdAt)}'),
            if (point.note != null) Text('Notiz: ${point.note}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePoint(point);
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editPoint(point);
            },
            child: const Text('Bearbeiten'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePoint(DepthPoint point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Punkt löschen?'),
        content: Text('Punkt #${point.pointNumber} (${point.depthM}m) unwiderruflich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && point.id != null) {
      await AppDatabase.instance.deleteDepthPoint(point.id!);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Punkt gelöscht')));
      }
    }
  }

  Future<void> _editPoint(DepthPoint point) async {
    final depthController = TextEditingController(text: point.depthM.toString());
    final noteController = TextEditingController(text: point.note ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Punkt #${point.pointNumber} bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: depthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Tiefe (m)', suffixText: 'm'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Notiz'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              final depth = double.tryParse(depthController.text.replaceAll(',', '.'));
              if (depth == null || depth <= 0) return;
              Navigator.pop(context, {
                'depthM': depth,
                'note': noteController.text.isEmpty ? null : noteController.text,
              });
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != null && point.id != null) {
      final updated = point.copyWith(
        depthM: result['depthM'],
        note: result['note'],
      );
      await AppDatabase.instance.updateDepthPoint(updated);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Punkt aktualisiert')));
      }
    }
  }

  Future<void> _saveCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      setState(() {
        _currentPosition = position;
      });

      if (position.accuracy > 10) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('GPS-Genauigkeit: ${position.accuracy.toStringAsFixed(1)} m (nicht optimal)')),
          );
        }
      }

      if (mounted) {
        _showSaveDepthDialog(LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS-Position konnte nicht ermittelt werden')),
        );
      }
    }
  }

  void _centerOnWammsee() {
    _mapController.move(_wammseeCenter, 16);
  }

  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiefen-Legende'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendItem('< 2 m', Colors.green[300]!),
            _legendItem('2-4 m', Colors.green[600]!),
            _legendItem('4-6 m', Colors.blue[300]!),
            _legendItem('6-8 m', Colors.blue[600]!),
            _legendItem('> 8 m', Colors.blue[900]!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}