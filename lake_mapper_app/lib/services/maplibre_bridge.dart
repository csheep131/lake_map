import 'dart:async';

/// Vereinfachter MapLibre Bridge
///
/// Diese Klasse dient als Brücke zwischen Flutter und MapLibre GL JS.
/// Die eigentliche Kommunikation läuft über window.eval() in maplibre_web.dart.
class MapLibreBridge {
  bool _isInitialized = false;

  /// Stream für Map-Bereitschaft
  final _mapReadyController = StreamController<bool>.broadcast();

  /// Stream für Map-Fehler
  final _mapErrorController = StreamController<String>.broadcast();

  /// Stream für Tap-Events
  final _mapTapController = StreamController<MapTapEvent>.broadcast();

  /// Stream für Move-Events
  final _mapMoveController = StreamController<MapMoveEvent>.broadcast();

  Stream<bool> get onMapReady => _mapReadyController.stream;
  Stream<String> get onMapError => _mapErrorController.stream;
  Stream<MapTapEvent> get onMapTap => _mapTapController.stream;
  Stream<MapMoveEvent> get onMapMove => _mapMoveController.stream;

  bool get isInitialized => _isInitialized;

  void markReady() {
    _isInitialized = true;
    _mapReadyController.add(true);
  }

  void markError(String error) {
    _mapErrorController.add(error);
  }

  void emitTap(MapTapEvent event) {
    _mapTapController.add(event);
  }

  void emitMove(MapMoveEvent event) {
    _mapMoveController.add(event);
  }

  void dispose() {
    _mapReadyController.close();
    _mapErrorController.close();
    _mapTapController.close();
    _mapMoveController.close();
  }
}

/// Tap-Event von der Karte
class MapTapEvent {
  final double lat;
  final double lng;
  final int timestamp;

  MapTapEvent({
    required this.lat,
    required this.lng,
    required this.timestamp,
  });
}

/// Move-Event von der Karte
class MapMoveEvent {
  final double lat;
  final double lng;
  final double zoom;

  MapMoveEvent({
    required this.lat,
    required this.lng,
    required this.zoom,
  });
}

/// Info-Typ für Debug-Daten
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
class DepthPointMap {
  final int? id;
  final double lat;
  final double lng;
  final double depth;
  final String? note;
  final int? timestamp;

  DepthPointMap({
    this.id,
    required this.lat,
    required this.lng,
    required this.depth,
    this.note,
    this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'depth': depth,
    'note': note ?? '',
    'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
    if (id != null) 'id': id,
  };
}
