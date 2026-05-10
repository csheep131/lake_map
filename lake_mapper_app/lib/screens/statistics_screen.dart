import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';
import '../models/lake.dart';
import '../theme/app_colors.dart';
import '../services/data_refresh_service.dart';
import 'package:intl/intl.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Lake> _lakes = [];
  Map<int, List<DepthPoint>> _pointsByLake = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    DataRefreshService.instance.addListener(_onRefresh);
  }

  void _onRefresh() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    DataRefreshService.instance.removeListener(_onRefresh);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final lakes = await AppDatabase.instance.getAllLakes();
      final pointsByLake = <int, List<DepthPoint>>{};

      for (final lake in lakes) {
        if (lake.id != null) {
          pointsByLake[lake.id!] = await AppDatabase.instance.getDepthPointsForLake(lake.id!);
        }
      }

      setState(() {
        _lakes = lakes;
        _pointsByLake = pointsByLake;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiken')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.cyan,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildOverviewCard(),
                  const SizedBox(height: 24),
                  ..._lakes.map((lake) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildLakeCard(lake),
                      )),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCard() {
    int totalPoints = 0;
    double minDepth = double.infinity;
    double maxDepth = double.negativeInfinity;
    double sumDepth = 0;

    for (final points in _pointsByLake.values) {
      for (final p in points) {
        totalPoints++;
        if (p.depthM < minDepth) minDepth = p.depthM;
        if (p.depthM > maxDepth) maxDepth = p.depthM;
        sumDepth += p.depthM;
      }
    }

    final avgDepth = totalPoints > 0 ? sumDepth / totalPoints : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.deep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceHighlight),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GESAMTÜBERSICHT',
                style: TextStyle(fontFamily: 'RobotoMono', 
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$totalPoints Punkte',
                  style: TextStyle(fontFamily: 'RobotoMono', 
                    fontSize: 11,
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _bigStat('SEEN', '${_lakes.length}')),
              Expanded(child: _bigStat('MIN', '${minDepth == double.infinity ? "—" : minDepth.toStringAsFixed(2)} m')),
              Expanded(child: _bigStat('MAX', '${maxDepth == double.negativeInfinity ? "—" : maxDepth.toStringAsFixed(2)} m')),
              Expanded(child: _bigStat('⌀', '${avgDepth.toStringAsFixed(2)} m')),
            ],
          ),
          if (totalPoints > 0) ...[
            const SizedBox(height: 20),
            _buildDepthDistributionChart(totalPoints),
          ],
        ],
      ),
    );
  }

  Widget _bigStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontFamily: 'RobotoMono', 
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontFamily: 'RobotoMono', 
            fontSize: 9,
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDepthDistributionChart(int totalPoints) {
    // Build real histogram buckets
    final buckets = <String, int>{
      '<2m': 0,
      '2-4m': 0,
      '4-6m': 0,
      '6-8m': 0,
      '>8m': 0,
    };

    for (final points in _pointsByLake.values) {
      for (final p in points) {
        if (p.depthM < 2) { buckets['<2m'] = buckets['<2m']! + 1; }
        else if (p.depthM < 4) { buckets['2-4m'] = buckets['2-4m']! + 1; }
        else if (p.depthM < 6) { buckets['4-6m'] = buckets['4-6m']! + 1; }
        else if (p.depthM < 8) { buckets['6-8m'] = buckets['6-8m']! + 1; }
        else { buckets['>8m'] = buckets['>8m']! + 1; }
      }
    }

    final maxCount = buckets.values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tiefenverteilung',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: buckets.entries.map((entry) {
            final ratio = maxCount > 0 ? entry.value / maxCount : 0.0;
            final colors = [
              AppColors.depthShallow,
              AppColors.depthMidShallow,
              AppColors.depthMid,
              AppColors.depthDeep,
              AppColors.depthAbyss,
            ];
            final idx = buckets.keys.toList().indexOf(entry.key);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  children: [
                    Text(
                      '${entry.value}',
                      style: TextStyle(fontFamily: 'RobotoMono', 
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 80 * ratio,
                      decoration: BoxDecoration(
                        color: colors[idx],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        boxShadow: [
                          BoxShadow(
                            color: colors[idx].withValues(alpha: 0.3),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.key,
                      style: TextStyle(fontFamily: 'RobotoMono', 
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLakeCard(Lake lake) {
    final points = _pointsByLake[lake.id] ?? [];
    final dateFormat = DateFormat('dd.MM.yyyy');

    double minDepth = double.infinity;
    double maxDepth = double.negativeInfinity;
    double sumDepth = 0;

    for (final p in points) {
      if (p.depthM < minDepth) minDepth = p.depthM;
      if (p.depthM > maxDepth) maxDepth = p.depthM;
      sumDepth += p.depthM;
    }

    final avgDepth = points.isNotEmpty ? sumDepth / points.length : 0.0;
    final firstPoint = points.isNotEmpty ? points.last : null;
    final lastPoint = points.isNotEmpty ? points.first : null;

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
              Text(
                lake.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${points.length} Punkte',
                  style: TextStyle(fontFamily: 'RobotoMono', 
                    fontSize: 11,
                    color: AppColors.cyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _statRow('Erstellt', dateFormat.format(lake.createdAt)),
          _statRow('Min Tiefe', '${minDepth == double.infinity ? "—" : minDepth.toStringAsFixed(2)} m'),
          _statRow('Max Tiefe', '${maxDepth == double.negativeInfinity ? "—" : maxDepth.toStringAsFixed(2)} m'),
          _statRow('⌀ Tiefe', '${avgDepth.toStringAsFixed(2)} m'),
          if (firstPoint != null)
            _statRow('Erster Punkt', dateFormat.format(firstPoint.createdAt)),
          if (lastPoint != null)
            _statRow('Letzter Punkt', dateFormat.format(lastPoint.createdAt)),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          Text(
            value,
            style: TextStyle(fontFamily: 'RobotoMono', 
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
