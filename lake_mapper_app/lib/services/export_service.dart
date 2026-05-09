import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/depth_point.dart';

class ExportService {
  static final ExportService instance = ExportService._init();

  ExportService._init();

  Future<String> exportToCsv(List<DepthPoint> points) async {
    final buffer = StringBuffer();
    buffer.writeln('latitude,longitude,depth_m,created_at,note');

    for (final point in points) {
      final note = point.note?.replaceAll(',', ';') ?? '';
      buffer.writeln(
        '${point.latitude},${point.longitude},${point.depthM},${point.createdAt.toIso8601String()},$note',
      );
    }

    return buffer.toString();
  }

  Future<String> exportToGeoJson(List<DepthPoint> points) async {
    final features = points.map((point) => {
      'type': 'Feature',
      'geometry': {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude, point.depthM],
      },
      'properties': {
        'depth_m': point.depthM,
        'created_at': point.createdAt.toIso8601String(),
        'note': point.note ?? '',
      },
    }).toList();

    final geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    return const JsonEncoder.withIndent('  ').convert(geoJson);
  }

  Future<File> saveToFile(String content, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    return file.writeAsString(content);
  }

  Future<String> getFilePath(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename';
  }
}