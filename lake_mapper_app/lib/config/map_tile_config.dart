/// Map Tile Configuration
/// Central configuration for tile providers
@Deprecated('Use MapConfig with PMTiles instead for offline vector maps')
class MapTileConfig {
  /// Current provider: change to use different tile source
  static final TileProvider provider = TileProvider.freeMap;

  /// Attribution text (required by most tile providers)
  static const String attribution = '© OpenStreetMap contributors';
}

/// Tile provider options
@Deprecated('Use MapConfig with PMTiles instead')
enum TileProvider {
  /// Free, no API key needed
  freeMap,
  
  /// MapTiler (requires API key)
  mapTiler,
  
  /// Mapbox (requires API key)
  mapbox,
  
  /// Thunderforest (requires API key)
  thunderforest,
}

/// Tile URLs and settings per provider
@Deprecated('Use MapConfig with PMTiles instead')
class TileSettings {
  // Free OpenStreetMap alternative: OpenFreeMap
  static const freeMapUrl = 'https://tiles.openfreemap.org/styles/liberty/{z}/{x}/{y}.png';
  static const freeMapAttrib = '© OpenStreetMap contributors, © OpenFreeMap';
  
  // MapTiler
  static const mapTilerUrl = 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=YOUR_API_KEY';
  static const mapTilerAttrib = '© MapTiler, © OpenStreetMap contributors';
  
  // Mapbox
  static const mapboxUrl = 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}?access_token=YOUR_API_KEY';
  static const mapboxAttrib = '© Mapbox, © OpenStreetMap contributors';
  
  // Thunderforest
  static const thunderforestUrl = 'https://tile.thunderforest.com/outdoors/{z}/{x}/{y}.png?apikey=YOUR_API_KEY';
  static const thunderforestAttrib = '© Thunderforest, © OpenStreetMap contributors';
}

/// Get URL template for current provider
@Deprecated('Use MapConfig with PMTiles instead')
String getTileUrl(TileProvider prov) {
  switch (prov) {
    case TileProvider.freeMap:
      return TileSettings.freeMapUrl;
    case TileProvider.mapTiler:
      return TileSettings.mapTilerUrl;
    case TileProvider.mapbox:
      return TileSettings.mapboxUrl;
    case TileProvider.thunderforest:
      return TileSettings.thunderforestUrl;
  }
}

/// Get attribution for current provider
@Deprecated('Use MapConfig with PMTiles instead')
String getAttribution(TileProvider prov) {
  switch (prov) {
    case TileProvider.freeMap:
      return TileSettings.freeMapAttrib;
    case TileProvider.mapTiler:
      return TileSettings.mapTilerAttrib;
    case TileProvider.mapbox:
      return TileSettings.mapboxAttrib;
    case TileProvider.thunderforest:
      return TileSettings.thunderforestAttrib;
  }
}