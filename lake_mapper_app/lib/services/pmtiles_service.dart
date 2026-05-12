import 'dart:io';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import '../config/map_config.dart';

class PmTilesService {
  static Future<VectorTileProvider> initTileProvider() async {
    String sourcePath;

    if (kIsWeb) {
      // On web, the asset is served from the server, we can use the URL path
      sourcePath = MapConfig.pmtilesAssetPath;
      debugPrint('PMTiles: Web detected, using asset URL: $sourcePath');
      return PmTilesVectorTileProvider.fromSource(sourcePath);
    } else {
      // On Android/iOS, copy the asset to a local file system path first
      debugPrint('PMTiles: Native platform detected, copying asset to local storage...');
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/wammsee.pmtiles');

      if (!await targetFile.exists()) {
        try {
          final byteData = await rootBundle.load(MapConfig.pmtilesAssetPath);
          await targetFile.writeAsBytes(
            byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          );
          debugPrint('PMTiles: Asset copied successfully to ${targetFile.path}');
        } catch (e) {
          debugPrint('PMTiles Error: Failed to copy asset - $e');
          rethrow;
        }
      } else {
        debugPrint('PMTiles: File already exists at ${targetFile.path}');
      }

      sourcePath = targetFile.path;
      return PmTilesVectorTileProvider.fromSource(sourcePath);
    }
  }

  static Theme getMapTheme() {
    // We use the light Protomaps theme as requested
    return ProtomapsThemes.light();
  }
}
