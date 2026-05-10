import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../services/sync_service.dart';
import '../theme/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _depthController = TextEditingController();
  final _noteController = TextEditingController();

  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSyncing = false;
  bool _isOnline = false;
  String? _syncStatus;
  int? _lastPointNumber;
  List<DepthPoint> _recentPoints = [];

  static const _accuracyWarningThreshold = 10.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await SyncService.instance.loadDatabaseName();
    await _loadRecentPoints();
    _loadCurrentPosition();
    _checkOnlineStatus();
  }

  Future<void> _loadRecentPoints() async {
    final points = await AppDatabase.instance.getAllDepthPoints();
    if (points.isNotEmpty) {
      _lastPointNumber = points.first.pointNumber;
    }
    _recentPoints = points.take(5).toList();
  }

  Future<void> _checkOnlineStatus() async {
    final online = await SyncService.instance.isOnline();
    setState(() => _isOnline = online);
  }

  Future<void> _sync() async {
    setState(() {
      _isSyncing = true;
      _syncStatus = 'Synchronisiere...';
    });

    try {
      final result = await SyncService.instance.syncAll();
      setState(() {
        _syncStatus = 'Hoch: ${result.uploaded} | Runter: ${result.downloaded}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_syncStatus!)),
        );
      }
    } catch (e) {
      setState(() {
        _syncStatus = 'Sync-Fehler';
      });
    } finally {
      setState(() => _isSyncing = false);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _syncStatus = null);
    }
  }

  @override
  void dispose() {
    _depthController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPosition() async {
    setState(() => _errorMessage = null);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() => _currentPosition = position);
    } catch (e) {
      setState(() => _errorMessage = 'GPS konnte nicht ermittelt werden');
    }
  }

  Future<void> _savePoint() async {
    final depthText = _depthController.text.trim();
    if (depthText.isEmpty) {
      _showError('Bitte Tiefe eingeben');
      return;
    }

    final depth = double.tryParse(depthText.replaceAll(',', '.'));
    if (depth == null || depth <= 0) {
      _showError('Bitte gültige Tiefe eingeben (> 0)');
      return;
    }

    if (_currentPosition == null) {
      _showError('Keine GPS-Position verfügbar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final point = DepthPoint(
        lakeId: 1,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        depthM: depth,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      await AppDatabase.instance.insertDepthPoint(point);

      _depthController.clear();
      _noteController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Messpunkt #$_lastPointNumber gespeichert'),
            backgroundColor: AppColors.cyan,
          ),
        );
        await _loadRecentPoints();
        _loadCurrentPosition();
      }
    } catch (e) {
      _showError('Fehler beim Speichern: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Color _getDepthColor(double depth) => AppColors.depthColor(depth);

  Future<void> _duplicateLastPoint() async {
    if (_lastPointNumber == null || _currentPosition == null) return;

    final lastPoint = _recentPoints.firstWhere((p) => p.pointNumber == _lastPointNumber);

    setState(() => _isLoading = true);

    try {
      final point = DepthPoint(
        lakeId: lastPoint.lakeId,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        depthM: lastPoint.depthM,
        note: lastPoint.note,
        createdAt: DateTime.now(),
      );

      await AppDatabase.instance.insertDepthPoint(point);
      _depthController.text = lastPoint.depthM.toString();
      _noteController.text = lastPoint.note ?? '';

      if (mounted) {
        await _loadRecentPoints();
        _loadCurrentPosition();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tiefe übernommen – GPS aktualisiert'),
              backgroundColor: AppColors.amber,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Fehler: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGpsCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHighlight),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPosition != null ? AppColors.success : AppColors.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_currentPosition != null ? AppColors.success : AppColors.error).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GPS SIGNAL',
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (_lastPointNumber != null)
                Text(
                  '#$_lastPointNumber',
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_currentPosition != null) ...[
            _buildCoordRow('LAT', _currentPosition!.latitude.toStringAsFixed(6)),
            const SizedBox(height: 4),
            _buildCoordRow('LON', _currentPosition!.longitude.toStringAsFixed(6)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Genauigkeit: ±${_currentPosition!.accuracy.toStringAsFixed(1)} m',
                  style: TextStyle(
                    fontSize: 12,
                    color: _currentPosition!.accuracy > _accuracyWarningThreshold
                        ? AppColors.amber
                        : AppColors.textSecondary,
                  ),
                ),
                if (_currentPosition!.accuracy > _accuracyWarningThreshold)
                  const Text(
                    '⚠ UNGENAU',
                    style: TextStyle(
                      color: AppColors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ] else if (_errorMessage != null) ...[
            Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadCurrentPosition,
              child: const Text('Erneut versuchen'),
            ),
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.cyan),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCoordRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.robotoMono(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDepthInput() {
    return TextField(
      controller: _depthController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.robotoMono(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.cyan,
      ),
      decoration: InputDecoration(
        labelText: 'TIEFE',
        labelStyle: GoogleFonts.robotoMono(
          fontSize: 11,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
        suffixText: 'm',
        suffixStyle: GoogleFonts.robotoMono(
          fontSize: 16,
          color: AppColors.textSecondary,
        ),
        prefixIcon: const Icon(Icons.straighten, color: AppColors.cyan),
      ),
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: const InputDecoration(
        labelText: 'Notiz (optional)',
        hintText: 'z. B. Kante, Schilf, Felsen',
        prefixIcon: Icon(Icons.edit_note, color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _savePoint,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.abyss),
              )
            : const Icon(Icons.save),
        label: const Text('MESSPUNKT SPEICHERN'),
      ),
    );
  }

  Widget _buildRecentPoints() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LETZTE PUNKTE',
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            if (_lastPointNumber != null)
              IconButton(
                onPressed: _isLoading ? null : _duplicateLastPoint,
                icon: const Icon(Icons.content_copy, size: 18),
                tooltip: 'Letzten Punkt duplizieren',
                color: AppColors.amber,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recentPoints.map((p) => _buildPointRow(p)),
      ],
    );
  }

  Widget _buildPointRow(DepthPoint p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.deep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surfaceHighlight),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getDepthColor(p.depthM),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _getDepthColor(p.depthM).withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${p.pointNumber}',
                style: GoogleFonts.robotoMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.depthM.toStringAsFixed(2)} m',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                if (p.note != null)
                  Text(
                    p.note!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '${p.latitude.toStringAsFixed(4)}°  ${p.longitude.toStringAsFixed(4)}°',
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lake Mapper'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                  )
                : Icon(_isOnline ? Icons.cloud_done : Icons.cloud_off),
            onPressed: _isSyncing ? null : _sync,
            tooltip: _isOnline ? 'Sync' : 'Offline',
            color: _isOnline ? AppColors.cyan : AppColors.textMuted,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_syncStatus != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _syncStatus!,
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      color: AppColors.cyan,
                    ),
                  ),
                ),
              _buildGpsCard(),
              const SizedBox(height: 20),
              _buildDepthInput(),
              const SizedBox(height: 12),
              _buildNoteInput(),
              const SizedBox(height: 24),
              _buildSaveButton(),
              const SizedBox(height: 32),
              if (_recentPoints.isNotEmpty) _buildRecentPoints(),
            ],
          ),
        ),
      ),
    );
  }
}
