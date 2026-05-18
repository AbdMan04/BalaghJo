import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0D1F3C);
  static const blue = Color(0xFF1B4FD8);
  static const sky = Color(0xFF4A9EFF);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const surface = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const textMuted = Color(0xFF64748B);

  // Quick Report tile backgrounds — from Claude Design handoff
  // (Quick Report Icons v2 — photo-faithful).
  static const tilePothole = Color(0xFFFFEAC9); // peach
  static const tileWaste = Color(0xFFDDF3E1); // mint
  static const tileLighting = Color(0xFFFFF1BF); // cream
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

ThemeData buildAppTheme() {
  const fontFamily = 'PlusJakartaSans';
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      primary: AppColors.navy,
      secondary: AppColors.blue,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.surface,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: fontFamily, bodyColor: AppColors.navy),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
  );
}
