import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
import '../config/map_config.dart';

Future<VectorTileProvider> initPmTilesProvider() async {
  final tempDir = await getTemporaryDirectory();
  final targetFile = File('${tempDir.path}/wammsee.pmtiles');

  if (!await targetFile.exists()) {
    final byteData = await rootBundle.load(MapConfig.pmtilesAssetPath);
    await targetFile.writeAsBytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
  }

  return PmTilesVectorTileProvider.fromSource(targetFile.path);
}

Theme getPmTilesTheme() {
  return ProtomapsThemes.light();
}
