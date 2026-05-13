import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// MapLibre Widget Placeholder
///
/// Dieses Widget wird für die MapLibre-Integration nicht mehr direkt verwendet.
/// Stattdessen wird die Karte direkt über JavaScript in map_screen_web.dart gesteuert.
class MapLibreWidget extends StatelessWidget {
  final String pmtilesUrl;
  final double initialLat;
  final double initialLng;
  final double initialZoom;
  final void Function(double lat, double lng)? onTap;
  final void Function(double lat, double lng, double zoom)? onMove;
  final bool showDebugPanel;

  const MapLibreWidget({
    super.key,
    required this.pmtilesUrl,
    this.initialLat = 49.3425,
    this.initialLng = 8.4495,
    this.initialZoom = 15.5,
    this.onTap,
    this.onMove,
    this.showDebugPanel = true,
  });

  @override
  Widget build(BuildContext context) {
    // Placeholder - MapLibre wird in map_screen_web.dart gesteuert
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'MapLibre Karte wird geladen...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
