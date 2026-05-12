import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService instance = LocationService._init();

  LocationService._init();

  Future<bool> checkPermission() async {
    // Auf Web: isLocationServiceEnabled() und checkPermission() funktionieren
    // nicht zuverlässig — der Browser handled Permissions automatisch beim
    // Aufruf von getCurrentPosition()
    if (kIsWeb) {
      return true;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    if (!kIsWeb) {
      final hasPermission = await checkPermission();
      if (!hasPermission) {
        return null;
      }
    }

    try {
      // Im Web: Browser zeigt automatisch die GPS-Berechtigung an
      // Geringere Genauigkeit und längerer Timeout für Web
      final accuracy = kIsWeb
          ? LocationAccuracy.medium
          : LocationAccuracy.high;
      final timeLimit = kIsWeb
          ? const Duration(seconds: 20)
          : const Duration(seconds: 10);

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<double> getAccuracy() async {
    final position = await getCurrentPosition();
    return position?.accuracy ?? -1;
  }
}