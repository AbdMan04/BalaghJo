// Shared location-error snackbars used by both map screens (explore map
// and the report-location picker) so the messaging can't drift apart.
import 'package:flutter/material.dart';

void showLocationPermissionDenied(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Location permission denied')),
  );
}

void showLocationUnavailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not get your location')),
  );
}
