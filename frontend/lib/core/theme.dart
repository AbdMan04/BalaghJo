import 'package:flutter/material.dart';
import 'page_transitions.dart';

// Civic "municipal board" palette: asphalt, warm paper, road-sign yellow.
// The legacy names (navy/blue/surface/border/textMuted) are kept as aliases
// so existing call sites keep compiling; new code should use the names below.
class AppColors {
  /// Asphalt — the primary surface/action color. Replaces the old navy.
  static const ink = Color(0xFF17191C);

  /// Warm off-white scaffold. Replaces the cool slate gray.
  static const paper = Color(0xFFF7F4EF);

  /// Deeper warm paper for nested shells and chart backdrops.
  static const paperDeep = Color(0xFFEFE9DF);

  /// Road-sign yellow — the single brand accent.
  static const safety = Color(0xFFFFC72B);

  /// Softer safety yellow for gradients and glows.
  static const safetySoft = Color(0xFFFFD84D);

  /// Asphalt lifted a step — hero gradients, hover fills on the sidebar.
  static const inkElevated = Color(0xFF23262C);

  /// Civic blue for links and interactive text only.
  static const link = Color(0xFF0B5CA8);

  /// Warm hairline for borders and dividers.
  static const line = Color(0xFFE3DED4);

  /// Secondary text.
  static const muted = Color(0xFF5B5F57);

  /// Amber confirm/acknowledge accent (road-sign hazard yellow).
  static const amber = Color(0xFFEAB308);

  // Semantic (traffic) colors.
  static const success = Color(0xFF1E7E34);
  static const warning = Color(0xFFE8A013);
  static const danger = Color(0xFFC63D2F);

  // Legacy aliases.
  static const navy = ink;
  static const blue = link;
  static const surface = paper;
  static const border = line;
  static const textMuted = muted;
  static const sky = Color(0xFFBBD6EE);

  /// Legacy accent used for charts/avatars; kept as a neutral slate-blue.
  static const calmBlue = Color(0xFF6B7482);

  // Category tile backgrounds, tuned to sit quietly on paper.
  static const tilePothole = Color(0xFFF4EBDC);
  static const tileWaste = Color(0xFFE4EEE3);
  static const tileLighting = Color(0xFFF5EFD6);
}

class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

ThemeData buildAppTheme() {
  const fontFamily = 'Cairo';
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.ink,
      primary: AppColors.ink,
      secondary: AppColors.safety,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.paper,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: fontFamily, bodyColor: AppColors.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      // Keep the bar pure white when content scrolls under it — M3's default
      // scrolled-under state tints it gray.
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      )
      // Flat, no shadow: solid fills and hairlines carry the structure.
      .copyWith(
        elevation: WidgetStateProperty.all(0),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
    ),
    // One horizontal-slide transition for every route on every platform.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: HorizontalSlideTransitionsBuilder(),
        TargetPlatform.iOS: HorizontalSlideTransitionsBuilder(),
        TargetPlatform.macOS: HorizontalSlideTransitionsBuilder(),
        TargetPlatform.windows: HorizontalSlideTransitionsBuilder(),
        TargetPlatform.linux: HorizontalSlideTransitionsBuilder(),
        TargetPlatform.fuchsia: HorizontalSlideTransitionsBuilder(),
      },
    ),
  );
}
