import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../models/lake.dart';

// Lake State
class LakesState {
  final List<Lake> lakes;
  final Lake? selectedLake;
  final bool isLoading;
  final String? error;

  const LakesState({
    this.lakes = const [],
    this.selectedLake,
    this.isLoading = false,
    this.error,
  });

  LakesState copyWith({
    List<Lake>? lakes,
    Lake? selectedLake,
    bool? isLoading,
    String? error,
  }) {
    return LakesState(
      lakes: lakes ?? this.lakes,
      selectedLake: selectedLake ?? this.selectedLake,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Lake Notifier
class LakeNotifier extends StateNotifier<LakesState> {
  LakeNotifier() : super(const LakesState());

  Future<void> loadLakes() async {
    state = state.copyWith(isLoading: true);
    try {
      final lakes = await AppDatabase.instance.getAllLakes();
      final selected = lakes.isNotEmpty ? lakes.first : null;
      state = state.copyWith(
        lakes: lakes,
        selectedLake: selected,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void selectLake(Lake lake) {
    state = state.copyWith(selectedLake: lake);
  }

  Future<void> addLake(String name) async {
    final newLake = Lake(
      name: name,
      createdAt: DateTime.now(),
    );
    await AppDatabase.instance.insertLake(newLake);
    await loadLakes();
  }
}

// Provider
final lakeProvider = StateNotifierProvider<LakeNotifier, LakesState>((ref) {
  return LakeNotifier();
});