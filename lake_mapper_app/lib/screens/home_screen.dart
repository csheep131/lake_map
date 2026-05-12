import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/data_refresh_service.dart';
import '../utils/geo_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../data/wammsee_polygon.dart';
import '../theme/app_colors.dart';
import '../services/web_gps_wrapper.dart';
import '../services/web_gps_state.dart';

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
  bool _isSearchingGps = false;
  String? _errorMessage;
  bool _isSyncing = false;
  bool _isOnline = false;
  String? _syncStatus;
  int? _lastPointNumber;
  List<DepthPoint> _recentPoints = [];

  WebGpsService? _webGpsService;
  WebGpsState _webGpsState = WebGpsState();

  double? get _currentLat => kIsWeb ? _webGpsState.latitude : _currentPosition?.latitude;
  double? get _currentLon => kIsWeb ? _webGpsState.longitude : _currentPosition?.longitude;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _webGpsService = getWebGpsService((newState) {
        if (mounted) {
          setState(() {
            _webGpsState = newState;
          });
        }
      });
    }
    _init();
    DataRefreshService.instance.addListener(_onRefresh);
  }

  void _onRefresh() {
    if (mounted) {
      _loadRecentPoints();
      _loadCurrentPosition();
    }
  }

  Future<void> _init() async {
    await SyncService.instance.loadDatabaseName();
    await _loadRecentPoints();
    _loadCurrentPosition();
    _checkOnlineStatus();
  }

  Future<void> _loadRecentPoints() async {
    final points = await AppDatabase.instance.getAllDepthPoints();
    if (mounted) {
      setState(() {
        if (points.isNotEmpty) {
          _lastPointNumber = points.first.pointNumber;
        }
        _recentPoints = points.take(50).toList();
      });
    }
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
        _syncStatus = 'Fehler: $e';
      });
    } finally {
      setState(() => _isSyncing = false);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _syncStatus = null);
    }
  }

  @override
  void dispose() {
    _webGpsService?.stop();
    DataRefreshService.instance.removeListener(_onRefresh);
    _depthController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPosition() async {
    if (kIsWeb) {
      _webGpsService?.checkStatusAndStart();
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSearchingGps = true;
    });

    try {
      // Erst Berechtigung prüfen/anfordern
      final hasPermission = await LocationService.instance.checkPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'GPS-Berechtigung fehlt!';
          _isSearchingGps = false;
        });
        // Dialog showen um Einstellungen zu öffnen
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('GPS-Berechtigung fehlt'),
            content: const Text('Die App braucht GPS-Zugriff. Bitte in den Einstellungen erlauben.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Geolocator.openAppSettings();
                },
                child: const Text('Einstellungen'),
              ),
            ],
          ),
        );
        return;
      }

      final position = await LocationService.instance.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isSearchingGps = false;
        if (position == null) {
          _errorMessage = 'GPS Zeitüberschreitung oder Fehler';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'GPS konnte nicht ermittelt werden';
        _isSearchingGps = false;
      });
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

    if (_currentLat == null || _currentLon == null) {
      _showError('Keine GPS-Position verfügbar');
      return;
    }

    final currentLatLng = LatLng(_currentLat!, _currentLon!);
    if (!isPointInPolygon(currentLatLng, wammseePolygon)) {
      _showError('GPS liegt außerhalb des Wammsee. Tiefenmessung nur im See möglich. Oder: Kartenansicht (Rechts) → manuell tippen');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final wammsee = await AppDatabase.instance.getOrCreateWammsee();
      final point = DepthPoint(
        lakeId: wammsee.id!,
        latitude: _currentLat!,
        longitude: _currentLon!,
        depthM: depth,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdAt: DateTime.now(),
      );

      try {
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
          DataRefreshService.instance.refresh();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Speichern: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
    if (_lastPointNumber == null || _currentLat == null || _currentLon == null) return;

    final lastPoint = _recentPoints.firstWhere((p) => p.pointNumber == _lastPointNumber);

    setState(() => _isLoading = true);

    try {
      final point = DepthPoint(
        lakeId: lastPoint.lakeId,
        latitude: _currentLat!,
        longitude: _currentLon!,
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

  Widget _buildWebGpsCard() {
    Color pointColor;
    String statusText;
    String? errorText;

    switch (_webGpsState.status) {
      case WebGpsStatus.available:
        pointColor = AppColors.success;
        statusText = 'GPS aktiv';
        break;
      case WebGpsStatus.checking:
      case WebGpsStatus.searching:
        pointColor = AppColors.amber;
        statusText = 'GPS wird gesucht...';
        break;
      case WebGpsStatus.desktopNoGps:
        pointColor = AppColors.error;
        statusText = 'Desktop ohne GPS';
        errorText = 'Kein GPS gefunden';
        break;
      case WebGpsStatus.permissionDenied:
        pointColor = AppColors.error;
        statusText = 'Standortberechtigung fehlt';
        errorText = _webGpsState.errorMessage;
        break;
      case WebGpsStatus.timeout:
        pointColor = AppColors.error;
        statusText = 'GPS Timeout';
        errorText = _webGpsState.errorMessage;
        break;
      case WebGpsStatus.error:
        pointColor = AppColors.error;
        statusText = 'GPS Fehler';
        errorText = _webGpsState.errorMessage;
        break;
      case WebGpsStatus.requiresHttps:
        pointColor = AppColors.error;
        statusText = 'Sicherheitsproblem';
        errorText = _webGpsState.errorMessage;
        break;
      case WebGpsStatus.unknown:
      default:
        pointColor = AppColors.textMuted;
        statusText = 'GPS Inaktiv';
        break;
    }

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
                      color: pointColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: pointColor.withValues(alpha: 0.4), blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusText.toUpperCase(),
                    style: TextStyle(fontFamily: 'RobotoMono', 
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: pointColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (_lastPointNumber != null)
                Text(
                  '#$_lastPointNumber',
                  style: TextStyle(fontFamily: 'RobotoMono', 
                    fontSize: 12,
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_webGpsState.status == WebGpsStatus.available) ...[
            _buildCoordRow('LAT', _webGpsState.latitude?.toStringAsFixed(6) ?? '-'),
            const SizedBox(height: 4),
            _buildCoordRow('LON', _webGpsState.longitude?.toStringAsFixed(6) ?? '-'),
            const SizedBox(height: 8),

          ] else if (errorText != null) ...[
            Text(errorText, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadCurrentPosition,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Erneut versuchen'),
              ),
            ),
          ] else if (_webGpsState.status == WebGpsStatus.searching || _webGpsState.status == WebGpsStatus.checking)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.cyan),
              ),
            )
          else ...[
            const Text('GPS wurde noch nicht gestartet.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadCurrentPosition,
                icon: const Icon(Icons.location_searching),
                label: const Text('GPS STARTEN'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                  foregroundColor: AppColors.cyan,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGpsCard() {
    if (kIsWeb) return _buildWebGpsCard();

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
                      color: _currentPosition != null 
                          ? AppColors.success 
                          : (_isSearchingGps ? AppColors.amber : AppColors.error),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_currentPosition != null 
                              ? AppColors.success 
                              : (_isSearchingGps ? AppColors.amber : AppColors.error)).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isSearchingGps ? 'GPS SUCHE...' : 'GPS SIGNAL',
                    style: TextStyle(fontFamily: 'RobotoMono', 
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _isSearchingGps ? AppColors.amber : AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              if (_lastPointNumber != null)
                Text(
                  '#$_lastPointNumber',
                  style: TextStyle(fontFamily: 'RobotoMono', 
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
            const SizedBox(height: 4),
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
            style: TextStyle(fontFamily: 'RobotoMono', 
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontFamily: 'RobotoMono', 
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
      style: TextStyle(fontFamily: 'RobotoMono', 
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.cyan,
      ),
      decoration: InputDecoration(
        labelText: 'TIEFE',
        labelStyle: TextStyle(fontFamily: 'RobotoMono', 
          fontSize: 11,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
        suffixText: 'm',
        suffixStyle: TextStyle(fontFamily: 'RobotoMono', 
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
    final bool hasGps = kIsWeb ? (_webGpsState.status == WebGpsStatus.available && _webGpsState.latitude != null) : _currentPosition != null;
    final bool inLake = hasGps && isPointInPolygon(
      LatLng(_currentLat!, _currentLon!),
      wammseePolygon,
    );
    final bool canSave = !_isLoading && hasGps && inLake;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: canSave ? _savePoint : null,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.abyss),
              )
            : const Icon(Icons.save),
        label: Text(
          !hasGps
              ? 'GPS WIRD GE SUCHT...'
              : !inLake
                  ? 'AUSSERHALB WAMMSEE'
                  : 'MESSPUNKT SPEICHERN',
        ),
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
              style: TextStyle(fontFamily: 'RobotoMono', 
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

  void _showPointActions(DepthPoint p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.edit, color: AppColors.cyan),
              title: const Text('Bearbeiten'),
              onTap: () {
                Navigator.pop(context);
                _editPoint(p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Löschen'),
              onTap: () {
                Navigator.pop(context);
                _deletePoint(p);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _editPoint(DepthPoint point) async {
    final depthController = TextEditingController(text: point.depthM.toString());
    final noteController = TextEditingController(text: point.note ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Punkt #${point.pointNumber} bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: depthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontFamily: 'RobotoMono', fontSize: 18, color: AppColors.cyan, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(labelText: 'Tiefe (m)', suffixText: 'm'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Notiz'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () {
              final depth = double.tryParse(depthController.text.replaceAll(',', '.'));
              if (depth == null || depth <= 0) return;
              Navigator.pop(context, {'depthM': depth, 'note': noteController.text.isEmpty ? null : noteController.text});
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != null && point.id != null) {
      final updated = point.copyWith(depthM: result['depthM'], note: result['note']);
      await AppDatabase.instance.updateDepthPoint(updated);
      await _loadRecentPoints();
      DataRefreshService.instance.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Punkt aktualisiert')));
      }
    }
  }

  Future<void> _deletePoint(DepthPoint point) async {
    if (point.id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Punkt löschen?'),
        content: Text('Punkt #${point.pointNumber} (${point.depthM}m) unwiderruflich löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.deleteDepthPoint(point.id!);
      await _loadRecentPoints();
      DataRefreshService.instance.refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Punkt gelöscht')));
      }
    }
  }

  Widget _buildPointRow(DepthPoint p) {
    return GestureDetector(
      onTap: () => _showPointActions(p),
      child: Container(
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
                  style: TextStyle(fontFamily: 'RobotoMono', 
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
              style: TextStyle(fontFamily: 'RobotoMono', 
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wammsee App'),
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
                    style: TextStyle(fontFamily: 'RobotoMono', 
                      fontSize: 11,
                      color: AppColors.cyan,
                    ),
                  ),
                ),
              if (!authService.isLoggedIn)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Bitte unter Setup anmelden um Daten zu synchronisieren.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.amber,
                          ),
                        ),
                      ),
                    ],
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
