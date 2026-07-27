// ReportCategory — single source of truth for every piece of UI data
// associated with a civic report category: backend API value, human
// label, optional quick-report subtitle and SVG illustration, the icon
// shown in small-context tiles, the accent tint, and the pastel tile
// background. Adding a new category is a one-line addition here.
//
// The top-level helper functions at the bottom of the file are thin
// wrappers around the enum, kept so existing call sites that work in
// terms of category strings don't all need to change at once.
import 'package:flutter/material.dart';
import '../../core/theme.dart';

enum ReportCategory {
  pothole(
    apiValue: 'pothole',
    label: 'Pothole',
    quickSubtitle: 'حُفرة',
    icon: Icons.report_problem_rounded,
    tint: AppColors.warning,
    tileBg: AppColors.tilePothole,
    svgAsset: 'assets/icons/quick_report/pothole.svg',
  ),
  waste(
    apiValue: 'waste',
    label: 'Waste',
    quickSubtitle: 'تراكُم نفايات',
    icon: Icons.recycling_rounded,
    tint: AppColors.success,
    tileBg: AppColors.tileWaste,
    svgAsset: 'assets/icons/quick_report/waste.svg',
  ),
  lighting(
    apiValue: 'lighting',
    label: 'Broken Light',
    quickSubtitle: 'إضاءة معطَّلة',
    icon: Icons.lightbulb_outline_rounded,
    tint: Color(0xFFEAB308),
    tileBg: AppColors.tileLighting,
    svgAsset: 'assets/icons/quick_report/lighting.svg',
  ),
  other(
    apiValue: 'other',
    label: 'Other',
    quickSubtitle: null,
    icon: Icons.report_outlined,
    tint: AppColors.blue,
    tileBg: AppColors.surface,
    svgAsset: null,
  );

  final String apiValue;
  final String label;
  final String? quickSubtitle;
  final IconData icon;
  final Color tint;
  final Color tileBg;
  final String? svgAsset;

  const ReportCategory({
    required this.apiValue,
    required this.label,
    required this.quickSubtitle,
    required this.icon,
    required this.tint,
    required this.tileBg,
    required this.svgAsset,
  });

  /// Categories the citizen can choose when submitting a report or
  /// filtering the list/map. `other` is reserved as a fallback for
  /// unrecognised values returned by older clients and is not shown
  /// in pickers.
  static const userSelectable = [pothole, waste, lighting, other];

  /// Resolve a backend category string (e.g. "pothole") to its
  /// [ReportCategory], falling back to [other] for unknown values.
  static ReportCategory fromApi(String? value) {
    for (final c in ReportCategory.values) {
      if (c.apiValue == value) return c;
    }
    return other;
  }
}

// Backward-compatible string-in / string-out helpers used by older
// call sites. New code should reach for [ReportCategory] directly.

IconData iconForCategory(String cat) => ReportCategory.fromApi(cat).icon;
Color colorForCategory(String cat) => ReportCategory.fromApi(cat).tint;
String labelForCategory(String cat, [BuildContext? ctx]) =>
    ReportCategory.fromApi(cat).label;
