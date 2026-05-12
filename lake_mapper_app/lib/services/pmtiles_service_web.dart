import 'package:flutter/foundation.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import '../config/map_config.dart';

Future<VectorTileProvider> initPmTilesProvider() async {
  // Use the full public URL to bypass any asset loading issues
  // We use the direct link to the file on the server
  final mapUrl = 'https://wammsee.arxlabs.dev/web/assets/assets/maps/wammsee.pmtiles';
  debugPrint('PMTiles: Loading from direct URL: $mapUrl');
  
  try {
    // Force usage of the HTTP source for web
    final archive = await PmTilesArchive.fromUri(Uri.parse(mapUrl));
    debugPrint('PMTiles: Archive opened successfully');
    return PmTilesVectorTileProvider.fromArchive(archive);
  } catch (e) {
    debugPrint('PMTiles Web Critical Error: $e');
    // Last ditch effort: simple network provider fallback (will likely be white if no server)
    return PmTilesVectorTileProvider.fromSource(mapUrl);
  }
}

Theme getPmTilesTheme() {
  // Extremely simple theme to avoid rendering overhead or crashes
  return ThemeReader().read({
    "version": 8,
    "sources": {
      "protomaps": {"type": "vector"}
    },
    "layers": [
      {
        "id": "background",
        "type": "background",
        "paint": {"background-color": "#e0e0e0"}
      },
      {
        "id": "water",
        "type": "fill",
        "source": "protomaps",
        "source-layer": "water",
        "paint": {"fill-color": "#a0cfdf"}
      }
    ]
  });
}
