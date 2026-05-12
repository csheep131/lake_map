import '../models/depth_point.dart';
import 'export_service_base.dart';

class WebExportService implements ExportService {
  @override
  Future<String> exportToCsv(List<DepthPoint> points) => exportToCsvStub(points);

  @override
  Future<String> exportToGeoJson(List<DepthPoint> points) => exportToGeoJsonStub(points);

  @override
  Future<dynamic> saveToFile(String content, String filename) async => null;

  @override
  Future<String> getFilePath(String filename) async => filename;
}

ExportService getExportService() => WebExportService();
