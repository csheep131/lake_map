import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';

import '../config/map_tile_config.dart'; // Deprecated, keep for reference
import '../config/map_config.dart';
import '../services/pmtiles_service.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../theme/app_colors.dart';
import '../data/wammsee_polygon.dart';
import '../services/data_refresh_service.dart';
import '../services/location_service.dart';
import '../utils/geo_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/web_gps_wrapper.dart';
import '../services/web_gps_state.dart';

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
  bool _abyssMode = false;
  bool _gpsLockMode = false;
  Timer? _gpsLockTimer;
  List<LatLng> _cachedGridPoints = [];
  List<Polygon> _cachedDepthContours = [];
  List<Polygon> _cachedAbyssDepthContours = [];
  List<Polyline> _cachedConnectionLines = [];
  List<Polyline> _cachedSonarGrid = [];
  
  WebGpsService? _webGpsService;
  WebGpsState _webGpsState = WebGpsState();
  VectorTileProvider? _vectorTileProvider;

  static const _wammseeCenter = LatLng(49.346970, 8.446897);

  @override
  void initState() {
    super.initState();
    _initVectorTiles();
    if (kIsWeb) {
      _webGpsService = getWebGpsService((newState) {
        if (mounted) {
          setState(() {
            _webGpsState = newState;
            if (newState.status == WebGpsStatus.available) {
               // Update position for the blue dot
               _currentPosition = Position(
                 latitude: newState.latitude ?? 0,
                 longitude: newState.longitude ?? 0,
                 timestamp: DateTime.now(),
                 accuracy: newState.accuracy ?? 0,
                 altitude: 0,
                 heading: 0,
                 speed: 0,
                 speedAccuracy: 0,
                 altitudeAccuracy: 0,
                 headingAccuracy: 0,
               );
            }
          });
        }
      });
      _webGpsService?.checkStatusAndStart();
    }
    _cachedGridPoints = _generateGridPoints();
    _loadData();
    DataRefreshService.instance.addListener(_onRefresh);
  }

  void _onRefresh() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _gpsLockTimer?.cancel();
    _webGpsService?.stop();
    DataRefreshService.instance.removeListener(_onRefresh);
    super.dispose();
  }

  Future<void> _initVectorTiles() async {
    try {
      final provider = await PmTilesService.initTileProvider();
      if (mounted) {
        setState(() {
          _vectorTileProvider = provider;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize PMTiles: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final wammsee = await AppDatabase.instance.getOrCreateWammsee();
      List<DepthPoint> points = [];
      if (wammsee.id != null) {
        points = await AppDatabase.instance.getDepthPointsForLake(wammsee.id!);
      }

      _cachedAbyssDepthContours = _buildAbyssDepthContourPolygons(points);
      _cachedConnectionLines = _buildConnectionLines(points);
      _cachedSonarGrid = _buildSonarGrid();

      if (!kIsWeb) {
        Position? position;
        try {
          position = await LocationService.instance.getCurrentPosition();
        } catch (e) {
          position = null;
        }
        setState(() => _currentPosition = position);
      }

      setState(() {
        _points = points;
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
  List<Polygon> _buildDepthContourPolygons(List<DepthPoint> points) {
    final contours = <Polygon>[];
    final buckets = <String, List<DepthPoint>>{
      'shallow': [],
      'midShallow': [],
      'mid': [],
      'deep': [],
      'abyss': [],
    };

    for (final p in points) {
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

  List<Polygon> _buildAbyssDepthContourPolygons(List<DepthPoint> points) {
    final contours = <Polygon>[];
    final buckets = <String, List<DepthPoint>>{
      'shallow': [],
      'midShallow': [],
      'mid': [],
      'deep': [],
      'abyss': [],
    };

    for (final p in points) {
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
          color: colors[i].withValues(alpha: 0.45),
          borderStrokeWidth: 2.5,
          borderColor: colors[i].withValues(alpha: 0.85),
        ));
      }
      i++;
    }
    return contours;
  }

  List<Polyline> _buildSonarGrid() {
    final bounds = _polygonBounds(wammseePolygon);
    final lines = <Polyline>[];
    const steps = 12;
    final dLat = (bounds['maxLat']! - bounds['minLat']!) / steps;
    final dLon = (bounds['maxLon']! - bounds['minLon']!) / steps;

    for (int i = 0; i <= steps; i++) {
      final lat = bounds['minLat']! + i * dLat;
      final lon = bounds['minLon']! + i * dLon;
      lines.add(Polyline(
        points: [
          LatLng(lat, bounds['minLon']!),
          LatLng(lat, bounds['maxLon']!),
        ],
        color: AppColors.sonarGrid.withValues(alpha: 0.15),
        strokeWidth: 0.5,
      ));
      lines.add(Polyline(
        points: [
          LatLng(bounds['minLat']!, lon),
          LatLng(bounds['maxLat']!, lon),
        ],
        color: AppColors.sonarGrid.withValues(alpha: 0.15),
        strokeWidth: 0.5,
      ));
    }
    return lines;
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
  List<Polyline> _buildConnectionLines(List<DepthPoint> points) {
    final lines = <Polyline>[];
    if (points.length < 2) return lines;

    // Connect each point to its 2 nearest neighbors
    for (int i = 0; i < points.length; i++) {
      final neighbors = _findNearestNeighbors(points, i, 2);
      for (final n in neighbors) {
        if (i < n) { // avoid duplicates
          lines.add(Polyline(
            points: [
              LatLng(points[i].latitude, points[i].longitude),
              LatLng(points[n].latitude, points[n].longitude),
            ],
            color: AppColors.cyan.withValues(alpha: 0.08),
            strokeWidth: 1,
          ));
        }
      }
    }
    return lines;
  }

  List<int> _findNearestNeighbors(List<DepthPoint> points, int index, int count) {
    final distances = <(int, double)>[];
    final p1 = points[index];
    for (int j = 0; j < points.length; j++) {
      if (j == index) continue;
      final p2 = points[j];
      final d = (p1.latitude - p2.latitude) * (p1.latitude - p2.latitude) +
                (p1.longitude - p2.longitude) * (p1.longitude - p2.longitude);
      distances.add((j, d));
    }
    distances.sort((a, b) => a.$2.compareTo(b.$2));
    return distances.take(count).map((e) => e.$1).toList();
  }

  void _onMapTap(TapPosition tapPosition, LatLng latlng) {
    // Check if tapped near an existing point (approx 30m threshold in degrees)
    const thresholdDeg = 0.0003;
    DepthPoint? nearestPoint;
    double nearestDist = double.infinity;
    for (final p in _points) {
      final d = (p.latitude - latlng.latitude) * (p.latitude - latlng.latitude) +
                (p.longitude - latlng.longitude) * (p.longitude - latlng.longitude);
      if (d < nearestDist) {
        nearestDist = d;
        nearestPoint = p;
      }
    }

    if (nearestPoint != null && nearestDist < thresholdDeg * thresholdDeg) {
      _showPointInfo(nearestPoint);
      return;
    }

    if (!isPointInPolygon(latlng, wammseePolygon)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Messpunkte können nur innerhalb des Wammsee eingetragen werden'),
          backgroundColor: AppColors.amber,
        ),
      );
      return;
    }
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
                style: TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: AppColors.cyan),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: depthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontFamily: 'RobotoMono', fontSize: 18, color: AppColors.cyan, fontWeight: FontWeight.w700),
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
      
      // Mit Fehlerbehandlung
      try {
        await AppDatabase.instance.insertDepthPoint(point);
        _loadData();
        DataRefreshService.instance.refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Messpunkt gespeichert')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler beim Speichern: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.surface,
                AppColors.deep,
                AppColors.abyss,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border(
              bottom: BorderSide(
                color: AppColors.cyan.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
          ),
        ),
        title: Text(
          'Wammsee',
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _glassIconButton(
              icon: _abyssMode ? Icons.explore : Icons.opacity,
              onPressed: () => setState(() => _abyssMode = !_abyssMode),
              tooltip: _abyssMode ? 'Kartenmodus' : 'Tiefenprofil',
              accentColor: _abyssMode ? AppColors.amber : AppColors.cyan,
              isActive: _abyssMode,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _glassIconButton(
              icon: Icons.info_outline,
              onPressed: _showLegend,
              tooltip: 'Legende',
              accentColor: AppColors.textSecondary,
              isActive: false,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _glassIconButton(
              icon: Icons.refresh,
              onPressed: _loadData,
              tooltip: 'Aktualisieren',
              accentColor: AppColors.cyan,
              isActive: false,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
          : Stack(
              children: [
                // Abyss / Bathymetry mode background
                if (_abyssMode)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.sonarBackground,
                          AppColors.navyDark,
                          AppColors.abyss,
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _points.isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.water, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 16),
                              Text(
                                'Noch keine Tiefenmessungen',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tippe auf die Karte um Punkte zu messen',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _points.isNotEmpty
                        ? LatLng(_points.first.latitude, _points.first.longitude)
                        : MapConfig.initialCenter,
                    initialZoom: MapConfig.initialZoom,
                    minZoom: MapConfig.minZoom,
                    maxZoom: MapConfig.maxZoom,
                    cameraConstraint: CameraConstraint.contain(bounds: MapConfig.cameraBounds),
                    onTap: _onMapTap,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    backgroundColor: _abyssMode ? Colors.transparent : const Color(0xFFF5F5F5),
                  ),
                  children: [
                    // PMTiles vector tiles only in map mode
                    if (!_abyssMode)
                      _vectorTileProvider != null
                          ? VectorTileLayer(
                              theme: PmTilesService.getMapTheme(),
                              tileProviders: TileProviders({
                                'protomaps': _vectorTileProvider!,
                              }),
                            )
                          : const Center(child: CircularProgressIndicator()),

                    // Water dot texture (map mode only)
                    if (!_abyssMode)
                      CircleLayer(
                        circles: _cachedGridPoints.map((p) => CircleMarker(
                          point: p,
                          radius: 1.2,
                          color: AppColors.cyan.withValues(alpha: 0.15),
                        )).toList(),
                      ),

                    // Sonar grid (abyss mode only)
                    if (_abyssMode && _cachedSonarGrid.isNotEmpty)
                      PolylineLayer(polylines: _cachedSonarGrid),

                    // Depth contour polygons (map mode)
                    if (!_abyssMode && _points.length >= 3)
                      PolygonLayer(polygons: _cachedDepthContours),

                    // Bathymetry depth zones (abyss mode)
                    if (_abyssMode && _points.length >= 3)
                      PolygonLayer(polygons: _cachedAbyssDepthContours),

                    // Connection lines for abyss mode
                    if (_abyssMode && _cachedConnectionLines.isNotEmpty)
                      PolylineLayer(polylines: _cachedConnectionLines),

                    // Lake polygon outline - abyss mode (bright sonar-style)
                    if (_abyssMode)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 10,
                            borderColor: AppColors.cyan.withValues(alpha: 0.12),
                          ),
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 5,
                            borderColor: AppColors.cyan.withValues(alpha: 0.35),
                          ),
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 2,
                            borderColor: AppColors.cyan.withValues(alpha: 0.9),
                          ),
                        ],
                      ),

                    // Lake polygon outline - map mode
                    if (!_abyssMode)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 8,
                            borderColor: AppColors.cyan.withValues(alpha: 0.08),
                          ),
                          Polygon(
                            points: wammseePolygon,
                            color: Colors.transparent,
                            borderStrokeWidth: 4,
                            borderColor: AppColors.cyan.withValues(alpha: 0.2),
                          ),
                          Polygon(
                            points: wammseePolygon,
                            color: AppColors.cyan.withValues(alpha: 0.08),
                            borderStrokeWidth: 2,
                            borderColor: AppColors.cyan.withValues(alpha: 0.7),
                          ),
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
                              'WAMMSEE',
                              style: TextStyle(fontFamily: 'RobotoMono',
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: _abyssMode
                                    ? AppColors.cyan.withValues(alpha: 0.15)
                                    : AppColors.cyan.withValues(alpha: 0.25),
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
                              width: _abyssMode ? 40 : 28,
                              height: _abyssMode ? 40 : 28,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _getDepthColor(point.depthM),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _abyssMode ? AppColors.textPrimary : AppColors.abyss,
                                    width: _abyssMode ? 2.5 : 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _getDepthColor(point.depthM).withValues(alpha: _abyssMode ? 0.9 : 0.4),
                                      blurRadius: _abyssMode ? 20 : 8,
                                      spreadRadius: _abyssMode ? 5 : 1,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    '${point.pointNumber ?? "?"}',
                                    style: TextStyle(fontFamily: 'RobotoMono',
                                      color: Colors.black,
                                      fontSize: _abyssMode ? 11 : 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            )),
                        if (_currentPosition != null && isPointInPolygon(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), wammseePolygon))
                          Marker(
                            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                            width: 28,
                            height: 28,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.shade400,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(color: Colors.blue.shade400.withValues(alpha: 0.6), blurRadius: 16, spreadRadius: 6),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // GPS-Lock Status Overlay
                if (_gpsLockMode)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.navyDark.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.amber.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.amber.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.amber),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'GPS-EINRASTEN',
                                style: TextStyle(
                                  fontFamily: 'RobotoMono',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.amber,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Suche Signal…',
                                style: TextStyle(
                                  fontFamily: 'RobotoMono',
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bathymetry legend overlay (abyss mode only)
                if (_abyssMode && _points.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.navyDark.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.cyan.withValues(alpha: 0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.abyss.withValues(alpha: 0.6),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TIEFE',
                            style: TextStyle(
                              fontFamily: 'RobotoMono',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _legendItem('< 2 m', AppColors.depthShallow),
                          _legendItem('2–4 m', AppColors.depthMidShallow),
                          _legendItem('4–6 m', AppColors.depthMid),
                          _legendItem('6–8 m', AppColors.depthDeep),
                          _legendItem('> 8 m', AppColors.depthAbyss),
                        ],
                      ),
                    ),
                  ),

                // FAB control bar
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.deep.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.cyan.withValues(alpha: 0.18),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.abyss.withValues(alpha: 0.7),
                          blurRadius: 32,
                          spreadRadius: 4,
                          offset: const Offset(0, -4),
                        ),
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.06),
                          blurRadius: 20,
                          spreadRadius: 0,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _mapFAB(
                          Icons.my_location,
                          'GPS',
                          (_currentPosition != null && isPointInPolygon(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), wammseePolygon))
                              ? _saveCurrentLocation
                              : null,
                          disabledTooltip: 'Außerhalb',
                        ),
                        _mapFAB(
                          _gpsLockMode ? Icons.gps_fixed : Icons.gps_not_fixed,
                          _gpsLockMode ? 'Lock an' : 'GPS-Lock',
                          _toggleGpsLockMode,
                          isActive: _gpsLockMode,
                          accentColor: _gpsLockMode ? AppColors.amber : AppColors.cyan,
                        ),
                        _mapFAB(Icons.center_focus_strong, 'Zentrum', _centerOnWammsee),
                        _mapFAB(
                          Icons.add_location,
                          'Hinzufügen',
                          () => _showSaveDepthDialog(_wammseeCenter),
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _mapFAB(IconData icon, String tooltip, VoidCallback? onPressed, {String? disabledTooltip, bool isPrimary = false, bool isActive = false, Color accentColor = AppColors.cyan}) {
    final isDisabled = onPressed == null;
    final iconColor = isDisabled
        ? AppColors.textMuted.withValues(alpha: 0.4)
        : isPrimary
            ? AppColors.cyan
            : accentColor.withValues(alpha: 0.85);
    final bgColor = isDisabled
        ? AppColors.abyss.withValues(alpha: 0.5)
        : isPrimary
            ? AppColors.cyan.withValues(alpha: 0.12)
            : isActive
                ? accentColor.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05);
    final borderColor = isDisabled
        ? AppColors.surfaceHighlight.withValues(alpha: 0.15)
        : isPrimary
            ? AppColors.cyan.withValues(alpha: 0.4)
            : isActive
                ? accentColor.withValues(alpha: 0.5)
                : AppColors.cyan.withValues(alpha: 0.15);
    final glowColor = isDisabled
        ? Colors.transparent
        : isPrimary
            ? AppColors.cyan.withValues(alpha: 0.25)
            : isActive
                ? accentColor.withValues(alpha: 0.3)
                : AppColors.cyan.withValues(alpha: 0.08);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glowColor,
                blurRadius: isPrimary ? 14 : 8,
                spreadRadius: isPrimary ? 2 : 0,
              ),
            ],
          ),
          child: Material(
            color: bgColor,
            shape: CircleBorder(
              side: BorderSide(color: borderColor, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              splashColor: AppColors.cyan.withValues(alpha: 0.15),
              highlightColor: AppColors.cyan.withValues(alpha: 0.08),
              child: SizedBox(
                width: isPrimary ? 52 : 46,
                height: isPrimary ? 52 : 46,
                child: Icon(icon, size: isPrimary ? 24 : 22, color: iconColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isDisabled ? (disabledTooltip ?? tooltip) : tooltip,
          style: TextStyle(
            fontFamily: 'RobotoMono',
            fontSize: 9,
            letterSpacing: 0.3,
            color: isDisabled
                ? AppColors.textMuted.withValues(alpha: 0.35)
                : isPrimary
                    ? AppColors.cyan.withValues(alpha: 0.9)
                    : AppColors.textMuted.withValues(alpha: 0.8),
          ),
        ),
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
          style: TextStyle(fontFamily: 'RobotoMono', fontWeight: FontWeight.w700, color: AppColors.cyan),
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
            child: Text(label, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontFamily: 'RobotoMono', fontSize: 12, color: AppColors.textPrimary)),
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
      DataRefreshService.instance.refresh();
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
              style: TextStyle(fontFamily: 'RobotoMono', fontSize: 18, color: AppColors.cyan, fontWeight: FontWeight.w700),
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
      DataRefreshService.instance.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Punkt aktualisiert')));
      }
    }
  }

  void _toggleGpsLockMode() {
    setState(() => _gpsLockMode = !_gpsLockMode);
    if (_gpsLockMode) {
      _startGpsLockTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS-Einrasten aktiviert – suche perfektes Signal…')),
        );
      }
    } else {
      _gpsLockTimer?.cancel();
      _gpsLockTimer = null;
    }
  }

  void _startGpsLockTimer() {
    _gpsLockTimer?.cancel();
    _checkGpsLock(); // sofortiger erster Check
    _gpsLockTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkGpsLock());
  }

  Future<void> _checkGpsLock() async {
    if (!_gpsLockMode || !mounted) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 12)),
      );

      if (!mounted) return;

      setState(() => _currentPosition = position);

      final latLng = LatLng(position.latitude, position.longitude);
      final inside = isPointInPolygon(latLng, wammseePolygon);

      if (!inside) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS außerhalb Wammsee')),
        );
        return;
      }

      // "Perfekt" = Genauigkeit <= 5 m
      if (position.accuracy <= 5.0) {
        _gpsLockTimer?.cancel();
        setState(() => _gpsLockMode = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS-Lock perfekt – Messdialog geöffnet')),
        );
        _showSaveDepthDialog(latLng);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS-Signal noch nicht optimal – suche weiter…')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS-Lock: Kein Signal erhalten')),
        );
      }
    }
  }

  Future<void> _saveCurrentLocation() async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPS wird optimiert…'), duration: Duration(seconds: 1)),
      );
    }

    Position? bestPosition;

    // Bis zu 3 Versuche, die beste Genauigkeit zu ermitteln
    for (int i = 0; i < 3; i++) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 8)),
        );
        if (bestPosition == null || position.accuracy < bestPosition.accuracy) {
          bestPosition = position;
        }
        if (bestPosition.accuracy <= 5.0) break; // perfekt, aufhören
        if (i < 2) await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        // Versuch fehlgeschlagen, nächster Durchlauf
      }
    }

    if (bestPosition == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS-Position konnte nicht ermittelt werden')),
        );
      }
      return;
    }

    setState(() => _currentPosition = bestPosition);

    if (mounted) {
      final latLng = LatLng(bestPosition.latitude, bestPosition.longitude);
      if (!isPointInPolygon(latLng, wammseePolygon)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS-Position liegt außerhalb des Wammsee'),
            backgroundColor: AppColors.amber,
          ),
        );
        return;
      }
      _showSaveDepthDialog(latLng);
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

  Widget _glassIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required Color accentColor,
    required bool isActive,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? accentColor.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: Icon(icon, size: 20),
            onPressed: onPressed,
            color: isActive ? accentColor : accentColor.withValues(alpha: 0.8),
            splashColor: accentColor.withValues(alpha: 0.15),
            highlightColor: accentColor.withValues(alpha: 0.1),
          ),
        ),
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
