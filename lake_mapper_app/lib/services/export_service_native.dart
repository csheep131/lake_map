import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/depth_point.dart';
import 'export_service_base.dart';

class NativeExportService implements ExportService {
  @override
  Future<String> exportToCsv(List<DepthPoint> points) => exportToCsvStub(points);

  @override
  Future<String> exportToGeoJson(List<DepthPoint> points) => exportToGeoJsonStub(points);

  @override
  Future<File> saveToFile(String content, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    return file.writeAsString(content);
  }

  @override
  Future<String> getFilePath(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename';
  }
}

ExportService getExportService() => NativeExportService();
