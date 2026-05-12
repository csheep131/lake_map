import 'web_gps_state.dart';
export 'web_gps_stub.dart' if (dart.library.html) 'web_gps_html.dart';

abstract class WebGpsService {
  Future<void> start();
  Future<void> checkStatusAndStart();
  void stop();
  WebGpsState get state;
}
