import 'package:flutter/foundation.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import '../config/map_config.dart';

Future<VectorTileProvider> initPmTilesProvider() async {
  final sourcePath = 'assets/${MapConfig.pmtilesAssetPath}';
  debugPrint('PMTiles: Web provider with path: $sourcePath');
  return PmTilesVectorTileProvider.fromSource(sourcePath);
}

Theme getPmTilesTheme() {
  return ProtomapsThemes.light();
}
