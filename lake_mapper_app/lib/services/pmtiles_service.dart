import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'pmtiles_service_stub.dart'
    if (dart.library.io) 'pmtiles_service_native.dart'
    if (dart.library.html) 'pmtiles_service_web.dart'
    if (dart.library.js_interop) 'pmtiles_service_web.dart';

class PmTilesService {
  static Future<VectorTileProvider> init() => initPmTilesProvider();
  static Theme getTheme() => getPmTilesTheme();
}
