// Report pins, clustering and legend for the reports map — FR-18 / FR-19.
//
// FR-18: every report with coordinates is drawn as a category-coloured pin.
// FR-19: when more than [kClusterThreshold] (50) pins fall inside the
// visible map, nearby pins are grouped into numbered cluster bubbles (grid
// clustering in screen pixels, recomputed as the camera moves); tapping a
// bubble zooms in on its reports. [MapLegend] shows the colour assigned to
// each category plus the cluster bubble.
//
// [clusterReports] is a pure function (projection and visibility are passed
// in) so the clustering rule is unit-testable without a live map.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/locale_state.dart';
import '../../../core/map_config.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../data/models/report.dart';
import '../../widgets/category_icon.dart';

/// FR-19: clustering activates when more pins than this are in the viewport.
const int kClusterThreshold = 50;

/// Pins whose screen positions share a grid cell of this size (in logical
/// pixels at the current zoom) are grouped into one cluster.
const double kClusterCellSize = 72;

class ReportCluster {
  final LatLng center;
  final List<Report> reports;
  const ReportCluster(this.center, this.reports);

  bool get isSingle => reports.length == 1;
}

/// Groups [reports] for display.
///
/// When at most [threshold] reports are visible (per [isVisible]), every
/// report stays an individual pin. Above it, reports are bucketed by the grid
/// cell their projected position ([project], in pixels at the current zoom)
/// falls in; a bucket with several reports becomes one cluster at their mean
/// position.
List<ReportCluster> clusterReports(
  List<Report> reports, {
  required math.Point<double> Function(LatLng) project,
  required bool Function(LatLng) isVisible,
  int threshold = kClusterThreshold,
  double cellSize = kClusterCellSize,
}) {
  LatLng pointOf(Report r) => LatLng(r.lat, r.lng);

  final visible = reports.where((r) => isVisible(pointOf(r))).length;
  if (visible <= threshold) {
    return [for (final r in reports) ReportCluster(pointOf(r), [r])];
  }

  final cells = <(int, int), List<Report>>{};
  for (final r in reports) {
    final p = project(pointOf(r));
    final key = ((p.x / cellSize).floor(), (p.y / cellSize).floor());
    (cells[key] ??= <Report>[]).add(r);
  }
  return [
    for (final members in cells.values)
      if (members.length == 1)
        ReportCluster(pointOf(members.first), members)
      else
        ReportCluster(
          LatLng(
            members.map((r) => r.lat).reduce((a, b) => a + b) / members.length,
            members.map((r) => r.lng).reduce((a, b) => a + b) / members.length,
          ),
          members,
        ),
  ];
}

/// Marker layer that renders [reports] as pins or cluster bubbles for the
/// current camera. Must be a child of a [FlutterMap]; it rebuilds whenever
/// the camera moves, so clusters split and merge as the user zooms.
class ReportClusterLayer extends StatelessWidget {
  final List<Report> reports;
  final String? selectedId;
  final ValueChanged<Report> onSelect;

  const ReportClusterLayer({
    super.key,
    required this.reports,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final bounds = camera.visibleBounds;
    final clusters = clusterReports(
      reports,
      project: (p) => camera.project(p),
      isVisible: bounds.contains,
    );
    return MarkerLayer(
      markers: [
        for (final c in clusters)
          if (c.isSingle)
            Marker(
              point: c.center,
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () => onSelect(c.reports.first),
                child: ReportPin(
                  category: c.reports.first.category,
                  active: selectedId == c.reports.first.id,
                ),
              ),
            )
          else
            Marker(
              point: c.center,
              width: ClusterBubble.sizeFor(c.reports.length),
              height: ClusterBubble.sizeFor(c.reports.length),
              child: GestureDetector(
                onTap: () => _zoomInto(context, camera, c),
                child: ClusterBubble(count: c.reports.length),
              ),
            ),
      ],
    );
  }

  void _zoomInto(BuildContext context, MapCamera camera, ReportCluster c) {
    final points = [for (final r in c.reports) LatLng(r.lat, r.lng)];
    final samePlace = points.every((p) => p == points.first);
    if (samePlace || camera.zoom >= MapConfig.maxZoom - 0.01) {
      // Can't be separated by zooming: open the newest report instead.
      onSelect(c.reports.first);
      return;
    }
    MapController.of(context).fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(64),
        maxZoom: MapConfig.maxZoom,
      ),
    );
  }
}

/// Category-coloured report pin.
class ReportPin extends StatelessWidget {
  final String category;
  final bool active;
  const ReportPin({super.key, required this.category, required this.active});

  @override
  Widget build(BuildContext context) {
    final tint = colorForCategory(category);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 40 : 32,
      height: active ? 40 : 32,
      decoration: BoxDecoration(
        color: tint,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: active ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: active ? 0.6 : 0.35),
            blurRadius: active ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(iconForCategory(category),
          color: Colors.white, size: active ? 20 : 16),
    );
  }
}

/// Numbered bubble standing in for a group of nearby reports.
class ClusterBubble extends StatelessWidget {
  final int count;
  const ClusterBubble({super.key, required this.count});

  static double sizeFor(int count) => count < 10
      ? 38
      : count < 100
          ? 46
          : 54;

  @override
  Widget build(BuildContext context) {
    final size = sizeFor(count);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.ink,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.safety, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: count > 99 ? 12 : 13,
        ),
      ),
    );
  }
}

/// FR-19 legend: the colour of each category's pin plus the cluster bubble.
/// Collapsible; starts collapsed on narrow (phone) screens so it doesn't
/// cover the map.
class MapLegend extends StatefulWidget {
  const MapLegend({super.key});

  @override
  State<MapLegend> createState() => _MapLegendState();
}

class _MapLegendState extends State<MapLegend> {
  bool? _expanded;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleState>().isArabic;
    final expanded = _expanded ?? MediaQuery.sizeOf(context).width >= 600;
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        key: const Key('map_legend'),
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => setState(() => _expanded = !expanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.palette_outlined,
                      size: 15, color: AppColors.navy),
                  const SizedBox(width: 6),
                  Text(context.t('map.legend'),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 4),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more,
                      size: 16, color: AppColors.textMuted),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 6),
                for (final c in ReportCategory.userSelectable)
                  _LegendRow(
                    swatch: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: c.tint,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(c.icon, size: 9, color: Colors.white),
                    ),
                    label: c.localizedLabel(isArabic),
                  ),
                _LegendRow(
                  swatch: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.safety, width: 1.5),
                    ),
                    child: const Text('n',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                  ),
                  label: context.t('map.legend_cluster'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Widget swatch;
  final String label;
  const _LegendRow({required this.swatch, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          swatch,
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
