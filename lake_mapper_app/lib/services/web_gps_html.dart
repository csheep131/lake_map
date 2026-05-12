import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'web_gps_state.dart';
import 'web_gps_wrapper.dart';

class WebGpsServiceImpl implements WebGpsService {
  final void Function(WebGpsState) onStateChanged;
  WebGpsState _state = WebGpsState();
  StreamSubscription? _positionSub;
  Timer? _timeoutTimer;

  WebGpsServiceImpl(this.onStateChanged);

  @override
  WebGpsState get state => _state;

  void _updateState(WebGpsState newState) {
    _state = newState;
    onStateChanged(_state);
  }

  @override
  Future<void> checkStatusAndStart() async {
    _updateState(WebGpsState(status: WebGpsStatus.checking));
    
    debugPrint("Web GPS: kIsWeb is $kIsWeb");
    debugPrint("Web GPS: Checking status...");
    debugPrint("Web GPS: isSecureContext = ${html.window.isSecureContext}");
    
    // Check HTTPS (unless localhost)
    final hostname = html.window.location.hostname ?? '';
    final isLocalhost = hostname.contains('localhost') || hostname == '127.0.0.1';
    if (html.window.isSecureContext != true && !isLocalhost) {
      _updateState(WebGpsState(
        status: WebGpsStatus.requiresHttps,
        errorMessage: "GPS benötigt HTTPS oder localhost",
      ));
      return;
    }

    // Check Mobile vs Desktop
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isMobile = userAgent.contains('mobi') || userAgent.contains('android') || userAgent.contains('iphone');
    debugPrint("Web GPS: isMobile = $isMobile (userAgent: $userAgent)");

    if (!isMobile) {
      _updateState(WebGpsState(
        status: WebGpsStatus.desktopNoGps,
        errorMessage: "Desktop ohne GPS",
      ));
      return;
    }

    if (html.window.navigator.geolocation == null) {
      _updateState(WebGpsState(
        status: WebGpsStatus.error,
        errorMessage: "Geolocation wird nicht unterstützt",
      ));
      return;
    }

    await start();
  }

  @override
  Future<void> start() async {
    _updateState(WebGpsState(status: WebGpsStatus.searching));
    debugPrint("Web GPS: Requesting geolocation...");

    // Timeout-Timer (15 seconds)
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_state.status == WebGpsStatus.searching) {
        debugPrint("Web GPS: Timeout reached.");
        _updateState(WebGpsState(status: WebGpsStatus.timeout, errorMessage: "GPS Timeout"));
      }
    });

    try {
      final positionStream = html.window.navigator.geolocation.watchPosition(
        enableHighAccuracy: true,
        timeout: const Duration(milliseconds: 15000),
      );

      _positionSub = positionStream.listen((html.Geoposition pos) {
        _timeoutTimer?.cancel();
        final coords = pos.coords;
        if (coords != null) {
          debugPrint("Web GPS: Position received (Lat: ${coords.latitude}, Lon: ${coords.longitude}, Acc: ${coords.accuracy})");
          _updateState(WebGpsState(
            status: WebGpsStatus.available,
            latitude: coords.latitude?.toDouble(),
            longitude: coords.longitude?.toDouble(),
            accuracy: coords.accuracy?.toDouble(),
          ));
        } else {
           _updateState(WebGpsState(
            status: WebGpsStatus.error,
            errorMessage: "Keine Koordinaten empfangen",
          ));
        }
      }, onError: (dynamic error) {
        _timeoutTimer?.cancel();
        debugPrint("Web GPS Error: $error");
        if (error is html.PositionError) {
           if (error.code == 1) { // PERMISSION_DENIED
             _updateState(WebGpsState(status: WebGpsStatus.permissionDenied, errorMessage: "Standortberechtigung fehlt"));
           } else if (error.code == 2) { // POSITION_UNAVAILABLE
             _updateState(WebGpsState(status: WebGpsStatus.error, errorMessage: "GPS Position nicht verfügbar"));
           } else if (error.code == 3) { // TIMEOUT
             _updateState(WebGpsState(status: WebGpsStatus.timeout, errorMessage: "GPS Timeout"));
           } else {
             _updateState(WebGpsState(status: WebGpsStatus.error, errorMessage: "GPS Fehler: ${error.message}"));
           }
        } else {
          _updateState(WebGpsState(status: WebGpsStatus.error, errorMessage: "Unbekannter GPS Fehler"));
        }
      });
    } catch (e) {
      _timeoutTimer?.cancel();
      debugPrint("Web GPS Exception: $e");
      _updateState(WebGpsState(status: WebGpsStatus.error, errorMessage: "GPS Fehler: $e"));
    }
  }

  @override
  void stop() {
    _timeoutTimer?.cancel();
    _positionSub?.cancel();
  }
}

WebGpsService getWebGpsService(void Function(WebGpsState) onStateChanged) => WebGpsServiceImpl(onStateChanged);
