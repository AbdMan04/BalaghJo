// ReportsMapScreen / ReportsMapView — feature F7 (Map View of Reports).
//
// Full-screen flutter_map view of the reports in the visible area:
//  - FR-18: every report with valid coordinates is a category-coloured pin;
//    reports without coordinates (0,0) are left out. The view loads every
//    page of the viewport's reports (not just the first 500).
//  - FR-19: above 50 pins in the viewport, nearby pins merge into numbered
//    clusters (ReportClusterLayer), and a legend shows each category colour.
//    The same view backs the citizen map (ReportsMapScreen) and the admin
//    dashboard's Map tab, which passes its own [onOpenReport].
//  - NFR-10: the first render is timed into the perf log ("map_render").
// Tapping a pin shows a compact card; the data comes from GET
// /api/reports/public, which omits reporter PII.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config.dart';
import '../../core/date_format.dart';
import '../../core/location_helper.dart';
import '../../core/map_config.dart';
import '../../core/perf_log.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/location_snackbars.dart';
import '../widgets/status_badge.dart';
import 'report_detail_screen.dart';
import 'widgets/report_cluster_layer.dart';

/// Called when the user opens a report from the map's marker card.
typedef OpenReportCallback = Future<void> Function(
    BuildContext context, Report report);

class ReportsMapScreen extends StatelessWidget {
  const ReportsMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('map.title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ReportsMapView(
        onOpenReport: (ctx, report) => Navigator.of(ctx).push(
          instantRoute(ReportDetailScreen(reportId: report.id)),
        ),
      ),
    );
  }
}

class ReportsMapView extends StatefulWidget {
  final OpenReportCallback onOpenReport;
  const ReportsMapView({super.key, required this.onOpenReport});

  @override
  State<ReportsMapView> createState() => _ReportsMapViewState();
}

class _ReportsMapViewState extends State<ReportsMapView> {
  final MapController _map = MapController();
  final _api = ReportApi();
  final Stopwatch _renderClock = Stopwatch()..start();
  bool _renderLogged = false;
  late Future<List<Report>> _future;
  String? _categoryFilter;
  String? _statusFilter;
  Report? _selected;
  LatLng? _myLocation;
  bool _locating = false;
  Timer? _viewportTimer;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _viewportTimer?.cancel();
    super.dispose();
  }

  /// C5: only ask for the reports inside the current viewport. Falls back
  /// to "everything" before the map is ready (camera not attached yet).
  Future<List<Report>> _load() {
    LatLngBounds? bounds;
    try {
      bounds = _map.camera.visibleBounds;
    } catch (_) {
      bounds = null;
    }
    return _api
        .publicList(
          category: _categoryFilter,
          status: _statusFilter,
          bounds: bounds,
        )
        .then(_logFirstRender);
  }

  // NFR-10: time from opening the map to the first frame showing its pins.
  List<Report> _logFirstRender(List<Report> reports) {
    if (!_renderLogged) {
      _renderLogged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerfLog.event('map_render', {
          'ms': _renderClock.elapsedMilliseconds,
          'pins': reports.where(_hasCoords).length,
        });
      });
    }
    return reports;
  }

  void _refilter({bool keepSelection = false}) {
    setState(() {
      if (!keepSelection) _selected = null;
      _future = _load();
    });
  }

  // Refetch the viewport once the camera settles after any pan, zoom
  // (pinch, wheel, double tap, cluster tap) or fling. Debounced so a gesture
  // does not fire a refetch per frame.
  void _onMapEvent(MapEvent e) {
    final settled = e is MapEventWithMove ||
        e is MapEventMoveEnd ||
        e is MapEventFlingAnimationEnd ||
        e is MapEventDoubleTapZoomEnd ||
        e is MapEventRotateEnd;
    if (!settled) return;
    _viewportTimer?.cancel();
    _viewportTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _refilter(keepSelection: true);
    });
  }

  bool _hasCoords(Report r) => r.lat != 0 || r.lng != 0;

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final point = await LocationHelper.locateClamped();
      if (!mounted) return;
      if (point == null) {
        showLocationPermissionDenied(context);
        return;
      }
      setState(() => _myLocation = point);
      _map.move(point, MapConfig.locationZoom);
    } catch (_) {
      if (!mounted) return;
      showLocationUnavailable(context);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Report>>(
      future: _future,
      builder: (_, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final reports =
            (snap.data ?? const <Report>[]).where(_hasCoords).toList();
        return Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: MapConfig.irbidCenter,
                initialZoom: MapConfig.initialZoom,
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom,
                cameraConstraint: MapConfig.cameraConstraint(),
                onMapEvent: _onMapEvent,
              ),
              children: [
                MapConfig.tileLayer(),
                const SimpleAttributionWidget(
                  source: Text(
                    MapConfig.attribution,
                    style: TextStyle(fontSize: 9, color: AppColors.textMuted),
                  ),
                  alignment: Alignment.bottomLeft,
                ),
                ReportClusterLayer(
                  reports: reports,
                  selectedId: _selected?.id,
                  onSelect: (r) => setState(() => _selected = r),
                ),
                if (_myLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _myLocation!,
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        child: const _YouAreHereDot(),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: _FilterBar(
                category: _categoryFilter,
                status: _statusFilter,
                onCategory: (c) {
                  _categoryFilter = c;
                  _refilter();
                },
                onStatus: (s) {
                  _statusFilter = s;
                  _refilter();
                },
              ),
            ),
            const PositionedDirectional(
              top: 94,
              start: 12,
              child: MapLegend(),
            ),
            if (loading && reports.isEmpty)
              const Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(child: _LoadingChip()),
              ),
            if (!loading && reports.isEmpty)
              const Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(child: _EmptyChip()),
              ),
            if (_selected != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: _MarkerCard(
                  report: _selected!,
                  onOpen: () => widget.onOpenReport(context, _selected!),
                  onClose: () => setState(() => _selected = null),
                ),
              ),
            Positioned(
              right: 16,
              bottom: _selected != null ? 188 : 24,
              child: Tooltip(
                message: context.t('map.locate'),
                child: PressableScale(
                  onTap: _locating ? null : _locate,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10),
                      ],
                    ),
                    child: _locating
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.blue),
                          )
                        : const Icon(Icons.my_location,
                            color: AppColors.blue),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _YouAreHereDot extends StatelessWidget {
  const _YouAreHereDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.blue,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.5), blurRadius: 12),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? category;
  final String? status;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onStatus;
  const _FilterBar({
    required this.category,
    required this.status,
    required this.onCategory,
    required this.onStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          Builder(builder: (ctx) {
            return _scrollRow([
              _chip(ctx.t('status.all_status'), status == null,
                  () => onStatus(null), AppColors.navy),
              _chip(ctx.t('status.sent'), status == 'pending',
                  () => onStatus('pending'), AppColors.blue),
              _chip(ctx.t('status.processing'), status == 'in_progress',
                  () => onStatus('in_progress'), AppColors.warning),
              _chip(ctx.t('status.resolved'), status == 'resolved',
                  () => onStatus('resolved'), AppColors.success),
            ]);
          }),
          const SizedBox(height: 6),
          Builder(builder: (ctx) {
            return _scrollRow([
              _catChip(ctx.t('status.all'), null),
              ...ReportCategory.userSelectable
                  .map((c) => _catChip(c.label, c.apiValue)),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _scrollRow(List<Widget> children) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: children,
      ),
    );
  }

  Widget _chip(String label, bool active, VoidCallback onTap, Color tint) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? tint : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? tint : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _catChip(String label, String? value) {
    final active = category == value;
    final tint = value == null ? AppColors.navy : colorForCategory(value);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: PressableScale(
        onTap: () => onCategory(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? tint.withValues(alpha: 0.14) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? tint : AppColors.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) ...[
                Icon(iconForCategory(value),
                    size: 13, color: active ? tint : AppColors.textMuted),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: active ? tint : AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingChip extends StatelessWidget {
  const _LoadingChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.blue),
          ),
          const SizedBox(width: 8),
          Text(context.t('map.loading'),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyChip extends StatelessWidget {
  const _EmptyChip();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined,
              color: AppColors.textMuted, size: 16),
          const SizedBox(width: 6),
          Text(context.t('map.no_match'),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MarkerCard extends StatelessWidget {
  final Report report;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  const _MarkerCard(
      {required this.report, required this.onOpen, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final tint = colorForCategory(report.category);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 22,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: report.photoUrl.isNotEmpty
                      ? Image.network(
                          AppConfig.imageUrl(report.photoUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                              iconForCategory(report.category),
                              color: tint),
                        )
                      : Icon(iconForCategory(report.category), color: tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title.isNotEmpty
                            ? report.title
                            : labelForCategory(report.category, context),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.address.isNotEmpty
                            ? report.address
                            : context.t('map.unnamed_location'),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusBadge(report.status),
                          const SizedBox(width: 8),
                          Text(formatDate(report.createdAt),
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.textMuted),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 10),
            PressableScale(
              onTap: onOpen,
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(context.t('map.open_details'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
