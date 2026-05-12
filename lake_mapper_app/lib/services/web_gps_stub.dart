import 'web_gps_state.dart';
import 'web_gps_wrapper.dart';

class WebGpsServiceImpl implements WebGpsService {
  @override
  WebGpsState get state => WebGpsState(status: WebGpsStatus.unknown);

  @override
  Future<void> start() async {}

  @override
  Future<void> checkStatusAndStart() async {}

  @override
  void stop() {}
}

WebGpsService getWebGpsService(void Function(WebGpsState) onStateChanged) => WebGpsServiceImpl();
