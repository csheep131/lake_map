import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// Central configuration for the local PMTiles vector map
class MapConfig {
  /// Path to the local PMTiles file in assets
  static const String pmtilesAssetPath = 'assets/maps/wammsee.pmtiles';

  /// Maximum zoom level provided by the PMTiles source (MVT metadata)
  static const int sourceMaxZoom = 14;

  /// Minimum zoom level for the map view
  static const double minZoom = 13.0;

  /// Maximum zoom level for the map view (allows overzooming past sourceMaxZoom)
  static const double maxZoom = 20.0;

  /// Initial center focus for the map: Wammsee lake
  static const LatLng initialCenter = LatLng(49.3425, 8.4495);

  /// Initial zoom level to show the lake prominently
  static const double initialZoom = 15.5;

  /// Camera bounds to restrict panning outside the lake area
  static final LatLngBounds cameraBounds = LatLngBounds(
    const LatLng(49.3335, 8.4385), // South-West
    const LatLng(49.3515, 8.4595), // North-East
  );
}
