import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';

abstract class PmTilesService {
  Future<VectorTileProvider> initTileProvider();
  Theme getMapTheme();
  
  static Future<VectorTileProvider> init() => createService().initTileProvider();
  static Theme getTheme() => createService().getMapTheme();
}

PmTilesService createService() => throw UnsupportedError('Cannot create PmTilesService');
