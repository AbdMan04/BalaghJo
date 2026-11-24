// Area picker — FR-14 geographic filter for the admin report feed.
//
// The admin pans and zooms an Irbid map until it frames the area of interest;
// "Use this area" returns the visible map bounds, which the feed sends as the
// swLat/swLng/neLat/neLng box (ANDed with the category/status filters).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/map_config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';

/// Shows the picker; resolves to the chosen bounds, or null when cancelled.
Future<LatLngBounds?> showAreaPicker(BuildContext context,
    {LatLngBounds? initial}) {
  return showDialog<LatLngBounds>(
    context: context,
    builder: (_) => _AreaPickerDialog(initial: initial),
  );
}

class _AreaPickerDialog extends StatefulWidget {
  final LatLngBounds? initial;
  const _AreaPickerDialog({this.initial});

  @override
  State<_AreaPickerDialog> createState() => _AreaPickerDialogState();
}

class _AreaPickerDialogState extends State<_AreaPickerDialog> {
  final _map = MapController();

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final initial = widget.initial;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: math.min(screen.width, 760),
        height: math.min(screen.height * 0.85, 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.t('admin.area_title'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 4),
                  Text(context.t('admin.area_hint'),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12.5)),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: MapConfig.irbidCenter,
                      initialZoom: MapConfig.initialZoom,
                      initialCameraFit: initial == null
                          ? null
                          : CameraFit.bounds(bounds: initial),
                      minZoom: MapConfig.minZoom,
                      maxZoom: MapConfig.maxZoom,
                      cameraConstraint: MapConfig.cameraConstraint(),
                    ),
                    children: [MapConfig.tileLayer()],
                  ),
                  // The whole visible map is the filter area; frame it so
                  // that reads clearly.
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.safety, width: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.t('common.cancel')),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    key: const Key('area_apply'),
                    onPressed: () =>
                        Navigator.of(context).pop(_map.camera.visibleBounds),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(context.t('admin.area_apply')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
