import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

/// Central configuration for the Wammsee raster tile map
class MapConfig {
  /// Base URL for the pre-rendered raster tiles on the server
  static const String tileUrl = 'https://wammsee.arxlabs.dev/web/tiles/{z}/{x}/{y}.png';

  /// Maximum zoom level provided by the tile source (pre-rendered PNGs go up to zoom 14)
  static const int sourceMaxZoom = 14;

  /// Minimum zoom level for the map view
  static const double minZoom = 13.0;

  /// Maximum zoom level for the map view
  /// flutter_map oversamps zoom-14 tiles when the user zooms to 15+ (smooth)
  static const double maxZoom = 18.0;

  /// Initial center focus for the map: Wammsee lake (center between tile 5602 and 5603)
  static const LatLng initialCenter = LatLng(49.3466, 8.4485);

  /// Initial zoom level – matches our highest native tile resolution (14)
  /// Overzooming (flutter_map scales tiles) works but looks blurry above 14
  static const double initialZoom = 14.0;

  /// Camera bounds to restrict panning outside the lake area
  static final LatLngBounds cameraBounds = LatLngBounds(
    const LatLng(49.3250, 8.4355), // South-West (covers tile 5603)
    const LatLng(49.3550, 8.4620), // North-East (covers tile 5602)
  );
}
