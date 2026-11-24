// AdminReportsScreen — F5 / FR-13..15 report feed for the web dashboard.
//
// FR-13: paginated at 50 reports per page (server-side cursor), each row
// shows category, date, status, submitter, and a photo thumbnail.
// FR-14: status / category / map-area filters (and a free-text search)
// reduce the visible set; the backend ANDs the same filters in the query.
// NFR-8: the first page load is timed into the perf log ("dashboard_load").
// Rows open AdminReportDetailScreen for the photo + GPS + status workflow.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:provider/provider.dart';
import '../../core/config.dart';
import '../../core/date_format.dart';
import '../../core/debounced_search.dart';
import '../../core/locale_state.dart';
import '../../core/perf_log.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/admin_api.dart';
import '../../data/models/report.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/freshness_bar.dart';
import '../widgets/remote_view.dart';
import '../widgets/route_aware_polling.dart';
import '../widgets/status_badge.dart';
import 'admin_report_detail_screen.dart';
import 'area_picker_dialog.dart';

class AdminReportsScreen extends StatefulWidget {
  /// True while this tab is the selected dashboard tab; polling is gated on
  /// it so only the visible tab issues background refreshes.
  final bool active;
  const AdminReportsScreen({super.key, this.active = true});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with RouteAwarePolling {
  final _api = AdminApi();
  final _search = DebouncedSearch();
  final _listKey = GlobalKey<RemoteViewState<AdminReportPage>>();
  String? _pageCursor;
  String? _nextCursor;
  String? _statusFilter;
  String? _categoryFilter;
  LatLngBounds? _area;
  DateTime? _lastUpdated;
  final Stopwatch _loadClock = Stopwatch()..start();
  bool _loadLogged = false;

  @override
  Duration get pollInterval => const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _search.onQuery = () => _listKey.currentState?.reload();
    _search.attach();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Future<void> poll() async {
    if (!widget.active) return;
    _listKey.currentState?.reload();
  }

  @override
  void didUpdateWidget(AdminReportsScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _listKey.currentState?.reload();
  }

  void _reload() {
    setState(() => _pageCursor = null);
    _listKey.currentState?.reload();
  }

  Future<void> _pickArea() async {
    final picked = await showAreaPicker(context, initial: _area);
    if (picked == null || !mounted) return;
    setState(() => _area = picked);
    _reload();
  }

  // NFR-8: time from opening the dashboard feed to its first rendered page.
  void _logFirstLoad(AdminReportPage page) {
    if (_loadLogged) return;
    _loadLogged = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PerfLog.event('dashboard_load', {
        'ms': _loadClock.elapsedMilliseconds,
        'rows': page.reports.length,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          statusFilter: _statusFilter,
          categoryFilter: _categoryFilter,
          area: _area,
          onPickArea: _pickArea,
          onClearArea: () {
            setState(() => _area = null);
            _reload();
          },
          searchController: _search.controller,
          lastUpdated: _lastUpdated,
          onRefresh: poll,
          onStatus: (v) {
            setState(() => _statusFilter = v);
            _reload();
          },
          onCategory: (v) {
            setState(() => _categoryFilter = v);
            _reload();
          },
        ),
        Expanded(
          child: RemoteView<AdminReportPage>(
            key: _listKey,
            onData: (page) {
              _nextCursor = page.nextCursor;
              _logFirstLoad(page);
              if (mounted) setState(() => _lastUpdated = DateTime.now());
            },
            load: () => _api.listReports(
              status: _statusFilter,
              category: _categoryFilter,
              query: _search.query.isEmpty ? null : _search.query,
              area: _area,
              before: _pageCursor,
            ),
            isEmpty: (page) => page.reports.isEmpty,
            emptyMessage: context.t('admin.no_reports'),
            builder: (context, page) => Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: page.reports.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _AdminRow(
                      report: page.reports[i],
                      onTap: () async {
                        await Navigator.of(context).push(
                          instantRoute(
                              AdminReportDetailScreen(report: page.reports[i])),
                        );
                        // Status may have changed on the detail screen; refresh.
                        if (mounted) _listKey.currentState?.reload();
                      },
                    ),
                  ),
                ),
                _PagerBar(
                  nextCursor: _nextCursor,
                  prevCursor: _pageCursor,
                  onNext: () {
                    setState(() => _pageCursor = _nextCursor);
                    _listKey.currentState?.reload();
                  },
                  onPrev: () {
                    setState(() => _pageCursor = null);
                    _listKey.currentState?.reload();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? statusFilter;
  final String? categoryFilter;
  final LatLngBounds? area;
  final VoidCallback onPickArea;
  final VoidCallback onClearArea;
  final TextEditingController searchController;
  final DateTime? lastUpdated;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onCategory;

  const _FilterBar({
    required this.statusFilter,
    required this.categoryFilter,
    required this.area,
    required this.onPickArea,
    required this.onClearArea,
    required this.searchController,
    required this.lastUpdated,
    required this.onRefresh,
    required this.onStatus,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleState>().isArabic;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: context.t('admin.search_hint'),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _areaChip(context),
                const SizedBox(width: 8),
                _filterChip(context, context.t('status.all'), null,
                    statusFilter, onStatus),
                for (final s in ReportStatus.values)
                  _filterChip(context, s.localizedLabel(isArabic), s.apiValue,
                      statusFilter, onStatus),
                const SizedBox(width: 8),
                _filterChip(context, context.t('cat.all'), null, categoryFilter,
                    onCategory),
                for (final c in ReportCategory.values)
                  _filterChip(context, c.localizedLabel(isArabic), c.apiValue,
                      categoryFilter, onCategory),
              ],
            ),
          ),
          const SizedBox(height: 6),
          FreshnessBar(lastUpdated: lastUpdated, onRefresh: onRefresh),
        ],
      ),
    );
  }

  // FR-14 area filter: opens the map picker; when an area is set the chip
  // shows it as active with a clear (x) action.
  Widget _areaChip(BuildContext context) {
    final active = area != null;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        key: const Key('area_filter_chip'),
        avatar: Icon(Icons.map_outlined,
            size: 16, color: active ? Colors.white : AppColors.navy),
        label: Text(active
            ? context.t('admin.area_selected')
            : context.t('admin.area_any')),
        selected: active,
        showCheckmark: false,
        onPressed: onPickArea,
        onDeleted: active ? onClearArea : null,
        deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
        deleteButtonTooltipMessage: context.t('admin.area_clear'),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.navy,
        ),
        selectedColor: AppColors.navy,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }

  Widget _filterChip(BuildContext context, String label, String? value,
      String? current, ValueChanged<String?> onTap) {
    final selected = value == current;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(selected ? null : value),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.navy,
        ),
        selectedColor: AppColors.navy,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;
  const _AdminRow({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = ReportCategory.fromApi(report.category);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        // Ticket stub: category-coloured bar along the leading edge.
        border: Border(
          left: BorderSide(color: cat.tint, width: 3),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: report.photoUrl.isNotEmpty
                      ? Image.network(
                          AppConfig.imageUrl(report.photoUrl),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _thumbFallback(cat.icon, cat.tileBg),
                        )
                      : _thumbFallback(cat.icon, cat.tileBg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            report.reportId,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 0.6,
                              color: cat.tint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(report.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.title.isNotEmpty ? report.title : cat.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${report.reporterName.isEmpty ? '-' : report.reporterName}'
                        '${report.reporterPhone.isNotEmpty ? ' · ${report.reporterPhone}' : ''}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(cat.icon, color: cat.tint, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(report.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbFallback(IconData icon, Color bg) => Container(
        width: 56,
        height: 56,
        color: bg,
        child: Icon(icon, color: AppColors.textMuted, size: 26),
      );
}

class _PagerBar extends StatelessWidget {
  final String? nextCursor;
  final String? prevCursor;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  const _PagerBar({
    required this.nextCursor,
    required this.prevCursor,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: prevCursor == null ? null : onPrev,
            icon: const Icon(Icons.chevron_left),
            label: Text(context.t('admin.prev')),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: nextCursor == null ? null : onNext,
            icon: const Icon(Icons.chevron_right),
            label: Text(context.t('admin.next')),
          ),
        ],
      ),
    );
  }
}
