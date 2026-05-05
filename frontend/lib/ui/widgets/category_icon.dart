import 'package:flutter/material.dart';

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

String labelForCategory(String cat) {
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
