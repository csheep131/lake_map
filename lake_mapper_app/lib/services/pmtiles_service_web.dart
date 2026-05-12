import 'package:flutter/foundation.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import '../config/map_config.dart';

Future<VectorTileProvider> initPmTilesProvider() async {
  // Use the full URL to the asset to avoid any relative path resolution that might use File APIs
  // The asset path on the server is /web/assets/assets/maps/wammsee.pmtiles
  final assetUrl = 'assets/${MapConfig.pmtilesAssetPath}';
  debugPrint('PMTiles: Web provider with URL: $assetUrl');
  
  // PmTilesVectorTileProvider.fromSource on web should handle URLs
  return PmTilesVectorTileProvider.fromSource(assetUrl);
}

Theme getPmTilesTheme() {
  return ProtomapsThemes.light();
}
