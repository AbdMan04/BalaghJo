import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

IconData iconForCategory(String cat) {
  switch (cat) {
    case 'pothole':
      return Icons.warning_amber_rounded;
    case 'waste':
      return Icons.delete_outline;
    case 'lighting':
      return Icons.lightbulb_outline;
    case 'road_crack':
      return Icons.alt_route;
    default:
      return Icons.report_outlined;
  }
}

String labelForCategory(String cat, [BuildContext? ctx]) {
  if (ctx != null) {
    return ctx.t('cat.$cat');
  }
  switch (cat) {
    case 'pothole':
      return 'Pothole';
    case 'waste':
      return 'Waste';
    case 'lighting':
      return 'Lighting';
    case 'road_crack':
      return 'Road Crack';
    default:
      return 'Other';
  }
}

Color colorForCategory(String cat) {
  switch (cat) {
    case 'pothole':
      return AppColors.warning; // amber
    case 'waste':
      return AppColors.success; // green
    case 'lighting':
      return const Color(0xFFEAB308); // yellow
    case 'road_crack':
      return AppColors.danger; // red
    default:
      return AppColors.blue;
  }
}
