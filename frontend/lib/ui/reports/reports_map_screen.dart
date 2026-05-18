// ReportsMapScreen — feature F7 (Map View of Reports).
//
// Full-screen flutter_map view that renders every report in the
// system as a category-colored pin (FR-18) over OpenStreetMap tiles.
// Tapping a pin shows a compact card with category, status, and
// address. Backed by GET /api/reports/all, which deliberately omits
// reporter PII so users cannot be deanonymized from the map.
// Note: clustering (FR-19) is deferred to GP2.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/status_badge.dart';
import 'report_detail_screen.dart';

class ReportsMapScreen extends StatefulWidget {
  const ReportsMapScreen({super.key});

  @override
  State<ReportsMapScreen> createState() => _ReportsMapScreenState();
}

class _ReportsMapScreenState extends State<ReportsMapScreen> {
  static const _irbid = LatLng(32.5556, 35.8500);

  final MapController _map = MapController();
  final _api = ReportApi();
  late Future<List<Report>> _future;
  String? _categoryFilter;
  String? _statusFilter;
  Report? _selected;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Report>> _load() => _api.publicList(
        category: _categoryFilter,
        status: _statusFilter,
      );

  void _refilter() {
    setState(() {
      _selected = null;
      _future = _load();
    });
  }

  bool _hasCoords(Report r) => r.lat != 0 || r.lng != 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('map.title'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<List<Report>>(
        future: _future,
        builder: (_, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final reports = (snap.data ?? const <Report>[]).where(_hasCoords).toList();
          return Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: const MapOptions(
                  initialCenter: _irbid,
                  initialZoom: 12,
                  minZoom: 5,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.balaghjo.app',
                    maxZoom: 19,
                  ),
                  MarkerLayer(
                    markers: reports
                        .map((r) => Marker(
                              point: LatLng(r.lat, r.lng),
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: GestureDetector(
                                onTap: () => setState(() => _selected = r),
                                child: _Pin(
                                  category: r.category,
                                  active: _selected?.id == r.id,
                                ),
                              ),
                            ))
                        .toList(),
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
              if (loading)
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
                    onClose: () => setState(() => _selected = null),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final String category;
  final bool active;
  const _Pin({required this.category, required this.active});

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
              _chip(ctx.t('status.all_status'), status == null, () => onStatus(null), AppColors.navy),
              _chip(ctx.t('status.sent'), status == 'pending', () => onStatus('pending'), AppColors.blue),
              _chip(ctx.t('status.processing'), status == 'in_progress', () => onStatus('in_progress'),
                  AppColors.warning),
              _chip(ctx.t('status.resolved'), status == 'resolved', () => onStatus('resolved'),
                  AppColors.success),
            ]);
          }),
          const SizedBox(height: 6),
          Builder(builder: (ctx) {
            return _scrollRow([
              _catChip(ctx.t('status.all'), null),
              _catChip(ctx.t('cat.pothole'), 'pothole'),
              _catChip(ctx.t('cat.waste'), 'waste'),
              _catChip(ctx.t('cat.lighting'), 'lighting'),
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
            boxShadow: active
                ? [BoxShadow(color: tint.withValues(alpha: 0.35), blurRadius: 10)]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
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
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) ...[
                Icon(iconForCategory(value), size: 13, color: active ? tint : AppColors.textMuted),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
          ),
          const SizedBox(width: 8),
          Text(context.t('map.loading'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_outlined, color: AppColors.textMuted, size: 16),
          const SizedBox(width: 6),
          Text(context.t('map.no_match'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MarkerCard extends StatelessWidget {
  final Report report;
  final VoidCallback onClose;
  const _MarkerCard({required this.report, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final tint = colorForCategory(report.category);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 22, offset: const Offset(0, 8)),
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
                          '${AppConfig.apiBaseUrl}${report.photoUrl}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(iconForCategory(report.category), color: tint),
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
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        report.address.isNotEmpty
                            ? report.address
                            : '${report.lat.toStringAsFixed(4)}, ${report.lng.toStringAsFixed(4)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusBadge(report.status),
                          const SizedBox(width: 8),
                          Text(DateFormat.MMMd().format(report.createdAt),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 10),
            PressableScale(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(ReportDetailScreen(reportId: report.id)),
              ),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.navy, AppColors.blue],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(context.t('map.open_details'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
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
