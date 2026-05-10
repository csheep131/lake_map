import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../services/export_service.dart';
import '../theme/app_colors.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  bool _isLoading = false;

  Future<void> _exportCsv() async {
    setState(() => _isLoading = true);

    try {
      final points = await AppDatabase.instance.getAllDepthPoints();
      final csv = await ExportService.instance.exportToCsv(points);
      final path = await ExportService.instance.getFilePath('depth_points.csv');
      await ExportService.instance.saveToFile(csv, 'depth_points.csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV gespeichert: $path'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportGeoJson() async {
    setState(() => _isLoading = true);

    try {
      final points = await AppDatabase.instance.getAllDepthPoints();
      final geoJson = await ExportService.instance.exportToGeoJson(points);
      final path = await ExportService.instance.getFilePath('depth_points.geojson');
      await ExportService.instance.saveToFile(geoJson, 'depth_points.geojson');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GeoJSON gespeichert: $path'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildExportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceHighlight),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DATEN EXPORTIEREN',
                      style: TextStyle(fontFamily: 'RobotoMono', 
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildExportCard(
                      icon: Icons.table_chart,
                      title: 'CSV Export',
                      subtitle: 'Tabellarische Daten für Excel / Sheets',
                      onTap: _exportCsv,
                      accentColor: AppColors.cyan,
                    ),
                    const SizedBox(height: 12),
                    _buildExportCard(
                      icon: Icons.map,
                      title: 'GeoJSON Export',
                      subtitle: 'Geodaten für GIS-Software',
                      onTap: _exportGeoJson,
                      accentColor: AppColors.amber,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
