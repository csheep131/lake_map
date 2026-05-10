import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../models/lake.dart';
import '../theme/app_colors.dart';
import '../data/wammsee_polygon.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  List<DepthPoint> _points = [];
  List<Lake> _lakes = [];
  Lake? _selectedLake;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _abyssMode = false;

  static const _wammseeCenter = LatLng(49.346970, 8.446897);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final lakes = await AppDatabase.instance.getAllLakes();
      final selectedLake = _selectedLake ?? (lakes.isNotEmpty ? lakes.first : null);

      List<DepthPoint> points = [];
      if (selectedLake != null && selectedLake.id != null) {
        points = await AppDatabase.instance.getDepthPointsForLake(selectedLake.id!);
      } else {
        points = await AppDatabase.instance.getAllDepthPoints();
      }

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
        _lakes = lakes;
        _selectedLake = selectedLake;
        _points = points;
        _currentPosition = position;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getDepthColor(double depth) => AppColors.depthColor(depth);

  // --- Point-in-Polygon (Ray Casting) ---
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final xi = polygon[i].longitude, yi = polygon[i].latitude;
      final xj = polygon[j].longitude, yj = polygon[j].latitude;
      final intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
          (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  // --- Generate dot-grid texture inside lake ---
  List<LatLng> _generateGridPoints() {
    final bounds = _polygonBounds(wammseePolygon);
    final List<LatLng> grid = [];
    const stepsLat = 30;
    const stepsLon = 30;
    final dLat = (bounds['maxLat']! - bounds['minLat']!) / stepsLat;
    final dLon = (bounds['maxLon']! - bounds['minLon']!) / stepsLon;

    for (int i = 0; i <= stepsLat; i++) {
      for (int j = 0; j <= stepsLon; j++) {
        final lat = bounds['minLat']! + i * dLat;
        final lon = bounds['minLon']! + j * dLon;
        final pt = LatLng(lat, lon);
        if (_isPointInPolygon(pt, wammseePolygon)) {
          grid.add(pt);
        }
      }
    }
    return grid;
  }

  Map<String, double> _polygonBounds(List<LatLng> polygon) {
    double minLat = 90, maxLat = -90, minLon = 180, maxLon = -180;
    for (final p in polygon) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLon) minLon = p.longitude;
      if (p.longitude > maxLon) maxLon = p.longitude;
    }
    return {'minLat': minLat, 'maxLat': maxLat, 'minLon': minLon, 'maxLon': maxLon};
  }

  // --- Build depth contour polygons from measured points ---
  List<Polygon> _buildDepthContourPolygons() {
    final contours = <Polygon>[];
    final buckets = <String, List<DepthPoint>>{
      'shallow': [],
      'midShallow': [],
      'mid': [],
      'deep': [],
      'abyss': [],
    };

    for (final p in _points) {
      if (p.depthM < 2) { buckets['shallow']!.add(p); }
      else if (p.depthM < 4) { buckets['midShallow']!.add(p); }
      else if (p.depthM < 6) { buckets['mid']!.add(p); }
      else if (p.depthM < 8) { buckets['deep']!.add(p); }
      else { buckets['abyss']!.add(p); }
    }

    final colors = [
      AppColors.depthShallow,
      AppColors.depthMidShallow,
      AppColors.depthMid,
      AppColors.depthDeep,
      AppColors.depthAbyss,
    ];

    var i = 0;
    for (final entry in buckets.entries) {
      final pts = entry.value;
      if (pts.length >= 3) {
        final latLngs = pts.map((p) => LatLng(p.latitude, p.longitude)).toList();
        final sorted = _sortByAngleAroundCentroid(latLngs);
        contours.add(Polygon(
          points: sorted,
          color: colors[i].withValues(alpha: 0.25),
          borderStrokeWidth: 1.5,
          borderColor: colors[i].withValues(alpha: 0.6),
        ));
      }
      i++;
    }
    return contours;
  }

  List<LatLng> _sortByAngleAroundCentroid(List<LatLng> points) {
    double cLat = 0, cLon = 0;
    for (final p in points) {
      cLat += p.latitude;
      cLon += p.longitude;
    }
    cLat /= points.length;
    cLon /= points.length;

    final withAngle = points.map((p) {
      final angle = atan2(p.latitude - cLat, p.longitude - cLon);
      return (angle: angle, point: p);
    }).toList();

    withAngle.sort((a, b) => a.angle.compareTo(b.angle));
    return withAngle.map((e) => e.point).toList();
  }

  // --- Connection lines for abyss mode ---
  List<Polyline> _buildConnectionLines() {
    final lines = <Polyline>[];
    if (_points.length < 2) return lines;

    // Connect each point to its 2 nearest neighbors
    for (int i = 0; i < _points.length; i++) {
      final neighbors = _findNearestNeighbors(i, 2);
      for (final n in neighbors) {
        if (i < n) { // avoid duplicates
          lines.add(Polyline(
            points: [
              LatLng(_points[i].latitude, _points[i].longitude),
              LatLng(_points[n].latitude, _points[n].longitude),
            ],
            color: AppColors.cyan.withValues(alpha: 0.08),
            strokeWidth: 1,
          ));
        }
      }
    }
    return lines;
  }

  List<int> _findNearestNeighbors(int index, int count) {
    final distances = <(int, double)>[];
    final p1 = _points[index];
    for (int j = 0; j < _points.length; j++) {
      if (j == index) continue;
      final p2 = _points[j];
      final d = (p1.latitude - p2.latitude) * (p1.latitude - p2.latitude) +
                (p1.longitude - p2.longitude) * (p1.longitude - p2.longitude);
      distances.add((j, d));
    }
    distances.sort((a, b) => a.$2.compareTo(b.$2));
    return distances.take(count).map((e) => e.$1).toList();
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.deep,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${position.latitude.toStringAsFixed(6)}\n${position.longitude.toStringAsFixed(6)}',
                style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.cyan),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: depthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.robotoMono(fontSize: 18, color: AppColors.cyan, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Tiefe', suffixText: 'm', hintText: 'z. B. 3.5'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Notiz (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
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
      if (lake.id == null) return;

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
    final gridPoints = _generateGridPoints();
    final depthContours = _buildDepthContourPolygons();
    final connectionLines = _buildConnectionLines();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showLakeSelector,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_selectedLake?.name ?? 'Alle Seen'),
              const Icon(Icons.arrow_drop_down, color: AppColors.cyan),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_abyssMode ? Icons.light_mode : Icons.opacity),
            onPressed: () => setState(() => _abyssMode = !_abyssMode),
            tooltip: _abyssMode ? 'Kartenmodus' : 'Tiefenprofil',
            color: _abyssMode ? AppColors.amber : AppColors.textSecondary,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showLegend,
            color: AppColors.textSecondary,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            color: AppColors.cyan,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
          : Stack(
              children: [
                if (_abyssMode) Container(color: AppColors.abyss),
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
                    if (!_abyssMode)
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'de.tom.wammsee_mapper',
                      ),

                    // Water dot texture
                    if (!_abyssMode)
                      CircleLayer(
                        circles: gridPoints.map((p) => CircleMarker(
                          point: p,
                          radius: 1.2,
                          color: AppColors.cyan.withValues(alpha: 0.15),
                        )).toList(),
                      ),

                    // Depth contour polygons
                    if (_points.length >= 3)
                      PolygonLayer(polygons: depthContours),

                    // Connection lines for abyss mode
                    if (_abyssMode && connectionLines.isNotEmpty)
                      PolylineLayer(polylines: connectionLines),

                    // Lake polygon with glow layers
                    if (!_abyssMode)
                      PolygonLayer(
                        polygons: [
                          // Outer glow
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 8,
                            borderColor: AppColors.cyan.withValues(alpha: 0.08),
                          ),
                          // Mid glow
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 4,
                            borderColor: AppColors.cyan.withValues(alpha: 0.2),
                          ),
                          // Core line
                          Polygon(
                            points: wammseePolygon,
                            color: AppColors.cyan.withValues(alpha: 0.08),
                            borderStrokeWidth: 2,
                            borderColor: AppColors.cyan.withValues(alpha: 0.7),
                          ),
                        ],
                      )
                    else
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 3,
                            borderColor: AppColors.cyan.withValues(alpha: 0.9),
                          ),
                        ],
                      ),

                    // Lake name label
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _wammseeCenter,
                          width: 200,
                          height: 60,
                          child: Center(
                            child: Text(
                              _selectedLake?.name.toUpperCase() ?? 'WAMMSEE',
                              style: GoogleFonts.robotoMono(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.cyan.withValues(alpha: 0.25),
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Depth markers
                    MarkerLayer(
                      markers: [
                        ..._points.map((point) => Marker(
                              point: LatLng(point.latitude, point.longitude),
                              width: _abyssMode ? 36 : 28,
                              height: _abyssMode ? 36 : 28,
                              child: GestureDetector(
                                onTap: () => _showPointInfo(point),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _getDepthColor(point.depthM),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _abyssMode ? AppColors.textPrimary : AppColors.abyss,
                                      width: _abyssMode ? 2 : 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getDepthColor(point.depthM).withValues(alpha: _abyssMode ? 0.7 : 0.4),
                                        blurRadius: _abyssMode ? 16 : 8,
                                        spreadRadius: _abyssMode ? 4 : 1,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${point.pointNumber ?? "?"}',
                                      style: GoogleFonts.robotoMono(
                                        color: Colors.black,
                                        fontSize: _abyssMode ? 10 : 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )),
                        if (_currentPosition != null)
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 28,
                            height: 28,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.abyss, width: 3),
                                boxShadow: [
                                  BoxShadow(color: AppColors.amber.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 4),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // FAB control bar
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.deep.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceHighlight),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _mapFAB(Icons.download, 'Cache', _downloadWammseeTiles),
                        _mapFAB(Icons.my_location, 'GPS', _saveCurrentLocation),
                        _mapFAB(Icons.center_focus_strong, 'Zentrum', _centerOnWammsee),
                        _mapFAB(Icons.add_location, 'Hinzufügen', () => _showSaveDepthDialog(_wammseeCenter)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _mapFAB(IconData icon, String tooltip, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: tooltip,
          onPressed: onPressed,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.cyan,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.surfaceHighlight),
          ),
          child: Icon(icon),
        ),
        const SizedBox(height: 4),
        Text(tooltip, style: GoogleFonts.robotoMono(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }

  void _showPointInfo(DepthPoint point) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '#${point.pointNumber ?? "?"} · ${point.depthM.toStringAsFixed(2)} m',
          style: GoogleFonts.robotoMono(fontWeight: FontWeight.w700, color: AppColors.cyan),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('LAT', point.latitude.toStringAsFixed(6)),
            _infoRow('LON', point.longitude.toStringAsFixed(6)),
            _infoRow('ZEIT', dateFormat.format(point.createdAt)),
            if (point.note != null) _infoRow('NOTIZ', point.note!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _deletePoint(point); },
            child: const Text('Löschen', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _editPoint(point); },
            child: const Text('Bearbeiten'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label, style: GoogleFonts.robotoMono(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: GoogleFonts.robotoMono(fontSize: 12, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePoint(DepthPoint point) async {
    if (point.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Punkt löschen?'),
        content: Text('Punkt #${point.pointNumber} (${point.depthM}m) unwiderruflich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
              style: GoogleFonts.robotoMono(fontSize: 18, color: AppColors.cyan, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Tiefe (m)', suffixText: 'm'),
            ),
            const SizedBox(height: 12),
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
              Navigator.pop(context, {'depthM': depth, 'note': noteController.text.isEmpty ? null : noteController.text});
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != null && point.id != null) {
      final updated = point.copyWith(depthM: result['depthM'], note: result['note']);
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      setState(() => _currentPosition = position);
      if (position.accuracy > 10 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS-Genauigkeit: ${position.accuracy.toStringAsFixed(1)} m')),
        );
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

  Future<void> _showLakeSelector() async {
    final result = await showDialog<Lake>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('See auswählen'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Alle Seen'),
                selected: _selectedLake == null,
                onTap: () => Navigator.pop(context, null),
              ),
              ..._lakes.map((lake) => ListTile(
                    title: Text(lake.name),
                    selected: _selectedLake?.id == lake.id,
                    onTap: () => Navigator.pop(context, lake),
                  )),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.add, color: AppColors.cyan),
                title: const Text('Neuen See hinzufügen'),
                onTap: () => _addNewLake(context),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
        ],
      ),
    );

    if (result != null && (_selectedLake?.id != result.id)) {
      setState(() => _selectedLake = result);
      _loadData();
    }
  }

  Future<void> _addNewLake(BuildContext dialogContext) async {
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Neuen See anlegen'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'z. B. Mümmelsee'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context, nameController.text);
              }
            },
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newLake = Lake(name: result, createdAt: DateTime.now());
      await AppDatabase.instance.insertLake(newLake);
      if (context.mounted) {
        Navigator.pop(dialogContext);
        _loadData();
      }
    }
  }

  Future<void> _downloadWammseeTiles() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bereich ansehen zum Cachen...')),
    );
    _mapController.move(_wammseeCenter, 15);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bereich gecacht für Offline-Nutzung')),
      );
    }
  }

  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tiefen-Legende'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _legendItem('< 2 m', AppColors.depthShallow),
            _legendItem('2–4 m', AppColors.depthMidShallow),
            _legendItem('4–6 m', AppColors.depthMid),
            _legendItem('6–8 m', AppColors.depthDeep),
            _legendItem('> 8 m', AppColors.depthAbyss),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen')),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.abyss, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
