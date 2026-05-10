import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/depth_point.dart';

// DepthPoints State
class DepthPointsState {
  final List<DepthPoint> points;
  final bool isLoading;
  final String? error;

  const DepthPointsState({
    this.points = const [],
    this.isLoading = false,
    this.error,
  });

  DepthPointsState copyWith({
    List<DepthPoint>? points,
    bool? isLoading,
    String? error,
  }) {
    return DepthPointsState(
      points: points ?? this.points,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// DepthPoint Notifier
class DepthPointNotifier extends StateNotifier<DepthPointsState> {
  final int? lakeId;

  DepthPointNotifier(this.lakeId) : super(const DepthPointsState());

  Future<void> loadPoints() async {
    state = state.copyWith(isLoading: true);
    try {
      List<DepthPoint> points;
      if (lakeId != null) {
        points = await AppDatabase.instance.getDepthPointsForLake(lakeId!);
      } else {
        points = await AppDatabase.instance.getAllDepthPoints();
      }
      state = state.copyWith(
        points: points,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> addPoint(DepthPoint point) async {
    try {
      await AppDatabase.instance.insertDepthPoint(point);
      await loadPoints();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updatePoint(DepthPoint point) async {
    try {
      await AppDatabase.instance.updateDepthPoint(point);
      await loadPoints();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deletePoint(int id) async {
    try {
      await AppDatabase.instance.deleteDepthPoint(id);
      await loadPoints();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

// Provider Family - mit lakeId
final depthPointProvider = StateNotifierProvider.family<DepthPointNotifier, DepthPointsState, int?>((ref, lakeId) {
  return DepthPointNotifier(lakeId);
});

// Statistics Provider
final lakeStatsProvider = Provider.family<LakeStats, int>((ref, lakeId) {
  final state = ref.watch(depthPointProvider(lakeId));
  return LakeStats.fromPoints(state.points);
});

class LakeStats {
  final int totalPoints;
  final double minDepth;
  final double maxDepth;
  final double avgDepth;

  const LakeStats({
    this.totalPoints = 0,
    this.maxDepth = 0,
    this.minDepth = 0,
    this.avgDepth = 0,
  });

  factory LakeStats.fromPoints(List<DepthPoint> points) {
    if (points.isEmpty) {
      return const LakeStats();
    }

    double min = double.infinity;
    double max = 0;
    double sum = 0;

    for (final p in points) {
      if (p.depthM < min) min = p.depthM;
      if (p.depthM > max) max = p.depthM;
      sum += p.depthM;
    }

    return LakeStats(
      totalPoints: points.length,
      minDepth: min,
      maxDepth: max,
      avgDepth: sum / points.length,
    );
  }
}