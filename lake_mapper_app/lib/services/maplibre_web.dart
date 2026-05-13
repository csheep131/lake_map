import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

/// MapLibre Service für Flutter Web
///
/// Initialisiert MapLibre GL JS mit PMTiles im Browser und bietet
/// eine Flutter-zugängliche API für GPS-Positionen und Tiefenpunkte.
class MapLibreService {
  static final MapLibreService _instance = MapLibreService._();
  static MapLibreService get instance => _instance;

  MapLibreService._();

  bool _isInitialized = false;
  final _readyController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _tapController = StreamController<MapTapData>.broadcast();
  final _moveController = StreamController<MapMoveData>.broadcast();

  Stream<bool> get onReady => _readyController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<MapTapData> get onTap => _tapController.stream;
  Stream<MapMoveData> get onMove => _moveController.stream;

  /// Prüfe ob MapLibre JS geladen ist
  Future<bool> checkMapLibreLoaded() async {
    try {
      // Warte kurz auf Script-Laden
      await Future.delayed(Duration(milliseconds: 500));
      return _isWindowReady();
    } catch (e) {
      debugPrint('MapLibre load check failed: $e');
      return false;
    }
  }

  bool _isWindowReady() {
    try {
      // Prüfe ob window.initMapLibreMap existiert durch Eval
      final jsCode = 'typeof window.initMapLibreMap === "function"';
      final result = globalContext.callMethod('eval'.toJS, jsCode.toJS);
      return result.toString() == 'true';
    } catch (e) {
      return false;
    }
  }

  /// Führe JavaScript-Code aus
  void evalJS(String code) {
    globalContext.callMethod('eval'.toJS, code.toJS);
  }

  /// Erstelle Map in einem Container
  Future<void> initMap({
    required String containerId,
    required String pmtilesUrl,
    double initialLat = 49.3425,
    double initialLng = 8.4495,
    double initialZoom = 15.5,
  }) async {
    try {
      // Warte bis der Container im DOM existiert (HtmlElementView Race Condition)
      final jsCode = '''
        (function() {
          var attempts = 0;
          var maxAttempts = 100;
          
          function tryInit() {
            attempts++;
            var container = document.getElementById('$containerId');
            
            if (container) {
              console.log('Map: Container gefunden nach ' + attempts + ' Versuchen');
              if (typeof window.initMapLibreMap === 'function') {
                window.initMapLibreMap('$containerId', '$pmtilesUrl', {
                  center: [$initialLng, $initialLat],
                  zoom: $initialZoom
                });
              } else {
                console.error('initMapLibreMap nicht gefunden');
              }
            } else if (attempts < maxAttempts) {
              setTimeout(tryInit, 100);
            } else {
              console.error('Map: Container $containerId nicht gefunden nach ' + maxAttempts + ' Versuchen');
            }
          }
          
          setTimeout(tryInit, 200);
        })();
      ''';

      evalJS(jsCode);
      _isInitialized = true;

      // Warte bis die Karte wirklich initialisiert ist (poll window._maplibreState.map)
      bool mapReady = false;
      for (int i = 0; i < 30; i++) {
        await Future.delayed(Duration(milliseconds: 300));
        try {
          final check = globalContext.callMethod('eval'.toJS,
            'window._maplibreState && window._maplibreState.map ? "ready" : "waiting"'.toJS);
          if (check.toString() == 'ready') {
            mapReady = true;
            break;
          }
        } catch (_) {}
      }

      if (mapReady) {
        // Wammsee-Polygon zeichnen
        _drawWammseePolygon();
        
        _readyController.add(true);
        
        // Tap-Polling starten (JS→Dart Callback-Brücke)
        _startTapPolling();
      } else {
        _errorController.add('Karte konnte nicht initialisiert werden');
      }

    } catch (e) {
      _errorController.add('Map Initialisierung fehlgeschlagen: $e');
    }
  }

  /// Wammsee-Polygon auf der Karte zeichnen
  void _drawWammseePolygon() {
    // Hardcoded Wammsee-Polygon Koordinaten (gleich wie in wammsee_polygon.dart)
    final jsCode = '''
      if (typeof window.drawWammseePolygon === 'function') {
        window.drawWammseePolygon([
          [49.3377254, 8.4481856],
          [49.3377596, 8.4478062],
          [49.3378036, 8.4474488],
          [49.3379039, 8.4468111],
          [49.3380173, 8.4463904],
          [49.3381671, 8.4460428],
          [49.3383479, 8.4456287],
          [49.3385149, 8.4453619],
          [49.3386272, 8.4452098],
          [49.3387617, 8.4451788],
          [49.3409174, 8.4454710],
          [49.3470848, 8.4464984],
          [49.3471647, 8.4466079],
          [49.3472385, 8.4469641],
          [49.3473173, 8.4473496],
          [49.3475760, 8.4494798],
          [49.3476020, 8.4497495],
          [49.3475922, 8.4501154],
          [49.3475604, 8.4506719],
          [49.3474866, 8.4511149],
          [49.3472964, 8.4518402],
          [49.3471937, 8.4519525],
          [49.3470892, 8.4519891],
          [49.3408598, 8.4505239],
          [49.3399618, 8.4502800],
          [49.3395307, 8.4501303],
          [49.3379323, 8.4487278],
          [49.3378115, 8.4485930],
          [49.3377456, 8.4483951]
        ]);
        console.log('Map: Wammsee Polygon gezeichnet');
      }
    ''';
    evalJS(jsCode);
  }

  /// Polling für Tap-Events (JS → Dart)
  int? _lastTapTimestamp;
  
  void _startTapPolling() {
    // Alle 200ms prüfen ob ein neuer Tap registriert wurde
    Future.doWhile(() async {
      await Future.delayed(Duration(milliseconds: 200));
      if (!_isInitialized) return false;
      
      try {
        final result = globalContext.callMethod('eval'.toJS,
          'JSON.stringify(window._maplibreState.lastTap || null)'.toJS);
        final str = result.toString();
        if (str != 'null' && str.isNotEmpty) {
          // Parse tap data
          final tapStr = str.replaceAll('{', '').replaceAll('}', '').replaceAll('"', '');
          final parts = tapStr.split(',');
          double? lat, lng;
          int? ts;
          for (final part in parts) {
            final kv = part.split(':');
            if (kv.length == 2) {
              final key = kv[0].trim();
              final val = kv[1].trim();
              if (key == 'lat') lat = double.tryParse(val);
              if (key == 'lng') lng = double.tryParse(val);
              if (key == 'timestamp') ts = int.tryParse(val);
            }
          }
          
          if (lat != null && lng != null && ts != null && ts != _lastTapTimestamp) {
            _lastTapTimestamp = ts;
            _tapController.add(MapTapData(lat: lat, lng: lng, timestamp: ts));
          }
        }
      } catch (_) {}
      
      return _isInitialized; // weiter pollen solange initialized
    });
  }

  /// GPS-Position setzen
  void setGpsPosition(double lat, double lng, double accuracy) {
    if (!_isInitialized) return;

    final jsCode = '''
      if (typeof window.setGpsPosition === 'function') {
        window.setGpsPosition($lat, $lng, $accuracy);
      }
    ''';
    evalJS(jsCode);
  }

  /// Tiefenpunkte setzen
  void setDepthPoints(List<MapDepthPoint> points) {
    if (!_isInitialized || points.isEmpty) return;

    final pointsJson = points.map((p) => '''
      {
        "lat": ${p.latitude},
        "lng": ${p.longitude},
        "depth": ${p.depth},
        "note": "${p.note ?? ''}"
      }
    ''').join(',');

    final jsCode = '''
      if (typeof window.setDepthPoints === 'function') {
        window.setDepthPoints([$pointsJson]);
      }
    ''';
    evalJS(jsCode);
  }

  /// Karte zentrieren
  void setMapCenter(double lat, double lng, {double? zoom}) {
    if (!_isInitialized) return;

    final zoomStr = zoom != null ? ', $zoom' : '';
    final jsCode = '''
      if (typeof window.setMapCenter === 'function') {
        window.setMapCenter($lat, $lng$zoomStr);
      }
    ''';
    evalJS(jsCode);
  }

  /// Zu Position fliegen
  void flyTo(double lat, double lng, {double? zoom}) {
    if (!_isInitialized) return;

    final zoomStr = zoom != null ? ', $zoom' : '';
    final jsCode = '''
      if (typeof window.flyTo === 'function') {
        window.flyTo($lat, $lng$zoomStr);
      }
    ''';
    evalJS(jsCode);
  }

  /// Debug-Info abrufen
  MapDebugInfo getDebugInfo() {
    // Default-Werte - echte Werte kommen vom JS
    return MapDebugInfo(
      pmtilesLoaded: _isInitialized,
      zoom: null,
      centerLat: null,
      centerLng: null,
      lastError: null,
      mapReady: _isInitialized,
    );
  }

  void dispose() {
    _readyController.close();
    _errorController.close();
    _tapController.close();
    _moveController.close();
  }
}

/// Daten für einen Map-Tap
class MapTapData {
  final double lat;
  final double lng;
  final int timestamp;

  MapTapData({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });
}

/// Daten für Map-Bewegung
class MapMoveData {
  final double lat;
  final double lng;
  final double zoom;

  MapMoveData({
    required this.lat,
    required this.lng,
    required this.zoom,
  });
}

/// Debug-Informationen
class MapDebugInfo {
  final bool pmtilesLoaded;
  final double? zoom;
  final double? centerLat;
  final double? centerLng;
  final String? lastError;
  final bool mapReady;

  MapDebugInfo({
    required this.pmtilesLoaded,
    this.zoom,
    this.centerLat,
    this.centerLng,
    this.lastError,
    required this.mapReady,
  });
}

/// Tiefenpunkt für die Karte
class MapDepthPoint {
  final double latitude;
  final double longitude;
  final double depth;
  final String? note;

  MapDepthPoint({
    required this.latitude,
    required this.longitude,
    required this.depth,
    this.note,
  });
}
