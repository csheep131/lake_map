import 'package:flutter/material.dart';

/// Abyss Instrument Color Palette
/// Inspired by deep-sea bathymetry displays and marine instruments.
/// Dark, high-contrast, functional. No pastels. No friendly defaults.
class AppColors {
  AppColors._();

  // --- Core Surface ---
  static const Color abyss = Color(0xFF050F1A);
  static const Color deep = Color(0xFF0A1929);
  static const Color surface = Color(0xFF132238);
  static const Color surfaceHighlight = Color(0xFF1B3352);

  // --- Primary: Bioluminescence Cyan ---
  static const Color cyan = Color(0xFF00E5CC);
  static const Color cyanMuted = Color(0xFF009E8C);
  static const Color cyanGlow = Color(0x4000E5CC);

  // --- Secondary / Accent: Warm Amber ---
  static const Color amber = Color(0xFFFFB347);
  static const Color amberMuted = Color(0xFFCC7A00);
  static const Color amberGlow = Color(0x40FFB347);

  // --- Text ---
  static const Color textPrimary = Color(0xFFE8F1F8);
  static const Color textSecondary = Color(0xFF8BA3BE);
  static const Color textMuted = Color(0xFF4A6585);

  // --- Functional ---
  static const Color error = Color(0xFFFF5A5A);
  static const Color success = Color(0xFF39FF14);
  static const Color warning = Color(0xFFFFD700);

  // --- Depth Gradient (replaces green/blue default slop) ---
  /// Shallow: warm cyan glow
  static const Color depthShallow = Color(0xFF7FFFD4);
  /// Medium-shallow: cyan
  static const Color depthMidShallow = Color(0xFF00CED1);
  /// Medium: teal
  static const Color depthMid = Color(0xFF008B8B);
  /// Deep: indigo
  static const Color depthDeep = Color(0xFF2E3A87);
  /// Abyssal: near-black violet
  static const Color depthAbyss = Color(0xFF1A0F3C);

  static Color depthColor(double depth) {
    if (depth < 2) return depthShallow;
    if (depth < 4) return depthMidShallow;
    if (depth < 6) return depthMid;
    if (depth < 8) return depthDeep;
    return depthAbyss;
  }

  static List<Color> get depthGradient => [
    depthShallow,
    depthMidShallow,
    depthMid,
    depthDeep,
    depthAbyss,
  ];
}
