import 'export_service_base.dart'
    if (dart.library.io) 'export_service_native.dart'
    if (dart.library.html) 'export_service_web.dart'
    if (dart.library.js_interop) 'export_service_web.dart';

class ExportService {
  static final instance = getExportService();
}