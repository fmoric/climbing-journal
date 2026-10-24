import 'package:flutter/material.dart';

/// Limestone ground, one teal accent; high contrast for outdoor light.
class AppColors {
  static const ground = Color(0xFFF4F2EE);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C1F1D);
  static const quiet = Color(0xFF5B605D);
  static const line = Color(0xFFD5D0C6);
  static const chip = Color(0xFFE6E2DA);
  static const accent = Color(0xFF0F6E6A);
  static const accentTint = Color(0x1F0F6E6A);
  static const warnBg = Color(0xFFFFF6E5);
  static const warnLine = Color(0xFFF0D9A8);
  static const warnInk = Color(0xFF5C3D00);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    surface: AppColors.ground,
    onSurface: AppColors.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ground,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accentTint,
    ),
  );
}
