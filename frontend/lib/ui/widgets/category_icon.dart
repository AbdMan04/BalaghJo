// ReportCategory — single source of truth for every piece of UI data
// associated with a civic report category: backend API value, human
// label, optional quick-report photo and Material icon, the accent
// tint, and the pastel tile background. Adding a new category is a
// one-line addition here.
//
// The top-level helper functions at the bottom of the file are thin
// wrappers around the enum, kept so existing call sites that work in
// terms of category strings don't all need to change at once.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale_state.dart';
import '../../core/theme.dart';
import '../../data/models/report.dart';

enum ReportCategory {
  pothole(
    apiValue: 'pothole',
    label: 'Pothole',
    labelAr: 'حُفرة',
    icon: Icons.report_problem_rounded,
    tint: AppColors.warning,
    tileBg: AppColors.tilePothole,
    photoAsset: 'assets/images/category_pothole.jpg',
  ),
  waste(
    apiValue: 'waste',
    label: 'Waste',
    labelAr: 'تراكُم نفايات',
    icon: Icons.recycling_rounded,
    tint: AppColors.success,
    tileBg: AppColors.tileWaste,
    photoAsset: 'assets/images/category_waste.jpg',
  ),
  lighting(
    apiValue: 'lighting',
    label: 'Broken Light',
    labelAr: 'إضاءة معطَّلة',
    icon: Icons.lightbulb_outline_rounded,
    tint: Color(0xFFEAB308),
    tileBg: AppColors.tileLighting,
    photoAsset: 'assets/images/category_lighting.jpg',
  ),
  other(
    apiValue: 'other',
    label: 'Other',
    labelAr: 'أخرى',
    icon: Icons.report_outlined,
    tint: AppColors.blue,
    tileBg: AppColors.surface,
    photoAsset: null,
  );

  final String apiValue;
  final String label;
  final String labelAr;
  final IconData icon;
  final Color tint;
  final Color tileBg;
  final String? photoAsset;

  const ReportCategory({
    required this.apiValue,
    required this.label,
    required this.labelAr,
    required this.icon,
    required this.tint,
    required this.tileBg,
    required this.photoAsset,
  });

  /// Label in the active language: English when English is selected,
  /// Arabic when Arabic is selected.
  String localizedLabel(bool isArabic) => isArabic ? labelAr : label;

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
// The locale is read from [BuildContext] so labels always match the
// active language; callers are expected to run under the LocaleState
// provider (the app root wraps MaterialApp in Consumer<LocaleState>).

IconData iconForCategory(String cat) => ReportCategory.fromApi(cat).icon;
Color colorForCategory(String cat) => ReportCategory.fromApi(cat).tint;

String labelForCategory(String cat, BuildContext context) =>
    ReportCategory.fromApi(cat)
        .localizedLabel(context.read<LocaleState>().isArabic);

// Fallback title used everywhere a report without a custom title still
// needs to be identifiable: show the custom title when present, else the
// localized category label.
String reportDisplayTitle(Report report, BuildContext context) =>
    report.title.isNotEmpty
        ? report.title
        : labelForCategory(report.category, context);

// Same idea for addresses: a report without a pinned address is shown as
// its category label instead.
String reportDisplayAddress(Report report, BuildContext context) =>
    report.address.isNotEmpty
        ? report.address
        : labelForCategory(report.category, context);
