enum WebGpsStatus {
  unknown,
  checking,
  desktopNoGps,
  permissionDenied,
  searching,
  available,
  timeout,
  error,
  requiresHttps
}

class WebGpsState {
  final WebGpsStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? errorMessage;

  WebGpsState({
    this.status = WebGpsStatus.unknown,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.errorMessage,
  });

  WebGpsState copyWith({
    WebGpsStatus? status,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? errorMessage,
  }) {
    return WebGpsState(
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
