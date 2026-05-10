import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { dark, family }

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.dark);

  void toggle() {
    state = state == AppThemeMode.dark ? AppThemeMode.family : AppThemeMode.dark;
  }

  void setFamily() {
    state = AppThemeMode.family;
  }

  void setDark() {
    state = AppThemeMode.dark;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});