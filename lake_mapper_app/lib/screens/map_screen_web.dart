import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';
import '../data/wammsee_polygon.dart';
import '../config/map_config.dart';
import '../utils/geo_utils.dart';
import '../services/auth_service.dart';

/// MapScreen für Flutter Web — bettet Leaflet-Karte direkt als DOM-Element ein.
/// Funktionalität analog zur nativen Android-App:
/// - Tap auf See → Tiefenpunkt-Erfassung
/// - "Zentrum"-Button → Karte auf Wammsee zentrieren
/// - "Hinzufügen"-Button → Dialog zum Eintragen
class MapScreenWeb extends StatefulWidget {
  const MapScreenWeb({super.key});

  @override
  State<MapScreenWeb> createState() => _MapScreenWebState();
}

class _MapScreenWebState extends State<MapScreenWeb> {
  static const _viewType = 'wammsee-map-div';
  static bool _registered = false;
  bool _mapReady = false;
  bool _isSaving = false;

  static const _baseUrl = 'https://wammsee.arxlabs.dev';

  @override
  void initState() {
    super.initState();
    _registerViewFactory();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _mapReady = true);
        _drawPolygon();
        _loadAndShowDepthPoints();
      }
    });
  }

  // ─── JS Bridge Helpers ────────────────────────────────────────────────────

  void _drawPolygon() {
    final jsCtx = js.context;
    if (jsCtx.hasProperty('drawWammseePolygon')) {
      jsCtx.callMethod('drawWammseePolygon', [
        js.JsObject.jsify(wammseePolygon.map((p) => [p.latitude, p.longitude]).toList())
      ]);
    }
  }

  void _centerOnWammsee() {
    final jsCtx = js.context;
    if (jsCtx.hasProperty('flyMapTo')) {
      jsCtx.callMethod('flyMapTo', [
        MapConfig.initialCenter.latitude,
        MapConfig.initialCenter.longitude,
        MapConfig.initialZoom,
      ]);
    }
  }

  // ─── API ──────────────────────────────────────────────────────────────────

  Future<void> _loadAndShowDepthPoints() async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = authService.token;
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final response = await http
          .get(Uri.parse('$_baseUrl/data'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final depths = data['depths'] as List<dynamic>? ?? [];
        final jsCtx = js.context;
        if (jsCtx.hasProperty('setDepthPoints')) {
          jsCtx.callMethod('setDepthPoints', [
            js.JsObject.jsify(depths.map((d) => {
              'lat': (d['latitude'] as num).toDouble(),
              'lng': (d['longitude'] as num).toDouble(),
              'depth': (d['depth_m'] as num).toDouble(),
              'number': d['id'] ?? 0,
            }).toList())
          ]);
        }
      }
    } catch (e) {
      debugPrint('[MapWeb] Fehler beim Laden der Tiefenpunkte: $e');
    }
  }

  Future<void> _saveDepthPoint({
    required double lat,
    required double lng,
    required double depth,
    String? note,
  }) async {
    if (!authService.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte zuerst einloggen'),
            backgroundColor: AppColors.amber,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/depths'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${authService.token}',
        },
        body: jsonEncode({
          'lake_id': 1,
          'depth_m': depth,
          'latitude': lat,
          'longitude': lng,
          'note': note,
        }),
      ).timeout(const Duration(seconds: 10));

      if (mounted) {
        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Messpunkt gespeichert'),
              backgroundColor: Colors.teal,
            ),
          );
          // Tiefenpunkte neu laden und auf Karte anzeigen
          await _loadAndShowDepthPoints();
        } else {
          final err = jsonDecode(response.body)['error'] ?? 'Fehler';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $err'), backgroundColor: AppColors.amber),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server nicht erreichbar: $e'), backgroundColor: AppColors.amber),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Dialog (analog Android) ──────────────────────────────────────────────

  Future<void> _showSaveDepthDialog(double lat, double lng) async {
    // Prüfen: Punkt im See?
    final isInLake = isPointInPolygon(
      LatLng(lat, lng),
      wammseePolygon,
    );

    if (!isInLake) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Messpunkte können nur innerhalb des Wammsee eingetragen werden'),
            backgroundColor: AppColors.amber,
          ),
        );
      }
      return;
    }

    final depthController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.deep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.3)),
        ),
        title: Text(
          'Messpunkt speichern',
          style: TextStyle(color: AppColors.textPrimary, fontFamily: 'RobotoMono'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navyDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
              ),
              child: Text(
                '${lat.toStringAsFixed(6)}\n${lng.toStringAsFixed(6)}',
                style: TextStyle(
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                  color: AppColors.cyan,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: depthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 18,
                color: AppColors.cyan,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: 'Tiefe',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                suffixText: 'm',
                suffixStyle: TextStyle(color: AppColors.textSecondary),
                hintText: 'z. B. 3.5',
                hintStyle: TextStyle(color: AppColors.textMuted),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notiz (optional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final depth = double.tryParse(depthController.text.replaceAll(',', '.'));
              if (depth == null || depth <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Bitte eine gültige Tiefe > 0 eingeben')),
                );
                return;
              }
              Navigator.pop(ctx, {
                'latitude': lat,
                'longitude': lng,
                'depthM': depth,
                'note': noteController.text.isEmpty ? null : noteController.text,
              });
            },
            child: Text('Speichern', style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result != null) {
      await _saveDepthPoint(
        lat: result['latitude'] as double,
        lng: result['longitude'] as double,
        depth: result['depthM'] as double,
        note: result['note'] as String?,
      );
    }
  }

  // ─── View Factory (Leaflet DOM) ───────────────────────────────────────────

  void _registerViewFactory() {
    if (_registered) return;
    _registered = true;

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final divId = 'wammsee-map-$viewId';
      final div = html.DivElement()
        ..id = divId
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.right = '0'
        ..style.bottom = '0'
        ..style.zIndex = '0';

      Future.delayed(const Duration(milliseconds: 500), () {
        final jsCtx = js.context;
        if (jsCtx.hasProperty('initMapLibreMap')) {
          jsCtx.callMethod('initMapLibreMap', [
            divId,
            'tiles',  // Relativ → /web/tiles/{z}/{x}/{y}.png (lokal gebündelt)
            js.JsObject.jsify({
              'center': [8.4475, 49.3425],  // [lng, lat]
              'zoom': 15.2,
            }),
          ]);

          // Tap-Callback: JS → Dart
          jsCtx['_maplibreState']['onMapTap'] = (dynamic tapData) {
            final lat = (tapData['lat'] as num).toDouble();
            final lng = (tapData['lng'] as num).toDouble();
            _showSaveDepthDialog(lat, lng);
          };
        } else {
          debugPrint('Error: initMapLibreMap not found on window');
        }
      });

      return div;
    });
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          const HtmlElementView(viewType: _viewType),

          // FAB control bar (Web Version — analog Android)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.deep.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cyan.withValues(alpha: 0.25), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _webFAB(Icons.center_focus_strong, 'Zentrum', _centerOnWammsee),
                  _webFAB(
                    Icons.refresh,
                    'Aktualisieren',
                    _loadAndShowDepthPoints,
                  ),
                  _webFAB(
                    Icons.add_location,
                    'Hinzufügen',
                    () => _showSaveDepthDialog(
                      MapConfig.initialCenter.latitude,
                      MapConfig.initialCenter.longitude,
                    ),
                    isPrimary: true,
                  ),
                ],
              ),
            ),
          ),

          // Speichern-Indikator
          if (_isSaving)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.navyDark.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.cyan,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Speichern...',
                        style: TextStyle(
                          color: AppColors.cyan,
                          fontFamily: 'RobotoMono',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Ladeindikator beim ersten Start
          if (!_mapReady)
            Container(
              color: AppColors.surface,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.cyan),
                    SizedBox(height: 16),
                    Text(
                      'Karte wird geladen...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'RobotoMono',
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _webFAB(IconData icon, String label, VoidCallback onPressed, {bool isPrimary = false}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.cyan.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary
                ? AppColors.cyan.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isPrimary ? AppColors.cyan : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? AppColors.cyan : AppColors.textSecondary,
                fontFamily: 'RobotoMono',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
