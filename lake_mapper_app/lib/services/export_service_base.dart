import 'dart:convert';
import '../models/depth_point.dart';

abstract class ExportService {
  Future<String> exportToCsv(List<DepthPoint> points);
  Future<String> exportToGeoJson(List<DepthPoint> points);
  Future<dynamic> saveToFile(String content, String filename);
  Future<String> getFilePath(String filename);
}

Future<String> exportToCsvStub(List<DepthPoint> points) async {
  final buffer = StringBuffer();
  buffer.writeln('latitude,longitude,depth_m,created_at,note');
  for (final point in points) {
    final note = point.note?.replaceAll(',', ';') ?? '';
    buffer.writeln('${point.latitude},${point.longitude},${point.depthM},${point.createdAt.toIso8601String()},$note');
  }
  return buffer.toString();
}

Future<String> exportToGeoJsonStub(List<DepthPoint> points) async {
  final features = points.map((point) => {
    'type': 'Feature',
    'geometry': {'type': 'Point', 'coordinates': [point.longitude, point.latitude, point.depthM]},
    'properties': {'depth_m': point.depthM, 'created_at': point.createdAt.toIso8601String(), 'note': point.note ?? ''},
  }).toList();
  return const JsonEncoder.withIndent('  ').convert({'type': 'FeatureCollection', 'features': features});
}

ExportService getExportService() => throw UnsupportedError('Stub');
