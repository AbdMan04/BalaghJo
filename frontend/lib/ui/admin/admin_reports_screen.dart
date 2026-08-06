// AdminReportsScreen — F5 / FR-13..15 report feed for the web dashboard.
//
// FR-13: paginated at 50 reports per page (server-side cursor), each row
// shows category, date, status, submitter, and a photo thumbnail.
// FR-14: status / category filters (and a free-text search) reduce the
// visible set; the backend applies the same filters to the query.
// Rows open AdminReportDetailScreen for the photo + GPS + status workflow.
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/admin_api.dart';
import '../../data/models/report.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/status_badge.dart';
import 'admin_report_detail_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  static const _statusOptions = ['pending', 'in_progress', 'resolved'];
  static const _categoryOptions = ['pothole', 'waste', 'lighting', 'other'];

  final _api = AdminApi();
  final _search = TextEditingController();
  Timer? _debounce;

  List<Report>? _reports;
  String? _error;
  bool _loading = true;
  String? _nextCursor;
  String? _prevCursor;
  String? _statusFilter;
  String? _categoryFilter;

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load();
    });
  }

  Future<void> _load({String? before}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _search.text.trim();
      final page = await _api.listReports(
        status: _statusFilter,
        category: _categoryFilter,
        query: query.isEmpty ? null : query,
        before: before,
      );
      if (!mounted) return;
      setState(() {
        _reports = page.reports;
        _nextCursor = page.nextCursor;
        _prevCursor = before;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          statusFilter: _statusFilter,
          categoryFilter: _categoryFilter,
          searchController: _search,
          onStatus: (v) {
            setState(() => _statusFilter = v);
            _load();
          },
          onCategory: (v) {
            setState(() => _categoryFilter = v);
            _load();
          },
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading && _reports == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.blue));
    }
    if (_error != null && _reports == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: Text(context.t('common.retry'))),
            ],
          ),
        ),
      );
    }
    final reports = _reports ?? const <Report>[];
    if (reports.isEmpty) {
      return Center(child: Text(context.t('admin.no_reports')));
    }
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AdminRow(
              report: reports[i],
              onTap: () async {
                await Navigator.of(context).push(
                  instantRoute(AdminReportDetailScreen(report: reports[i])),
                );
                // Status may have changed on the detail screen; refresh.
                if (mounted) _load(before: _prevCursor);
              },
            ),
          ),
        ),
        _PagerBar(
          nextCursor: _nextCursor,
          prevCursor: _prevCursor,
          onNext: () => _load(before: _nextCursor),
          onPrev: () => _load(before: null),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? statusFilter;
  final String? categoryFilter;
  final TextEditingController searchController;
  final ValueChanged<String?> onStatus;
  final ValueChanged<String?> onCategory;

  const _FilterBar({
    required this.statusFilter,
    required this.categoryFilter,
    required this.searchController,
    required this.onStatus,
    required this.onCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                _filterChip(context, context.t('status.all'), null, statusFilter, onStatus),
                for (final s in _AdminReportsScreenState._statusOptions)
                  _filterChip(context, _statusLabel(s), s, statusFilter, onStatus),
                const SizedBox(width: 8),
                _filterChip(context, context.t('cat.all'), null, categoryFilter, onCategory),
                for (final c in _AdminReportsScreenState._categoryOptions)
                  _filterChip(
                      context, ReportCategory.fromApi(c).label, c, categoryFilter, onCategory),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      BuildContext context, String label, String? value, String? current, ValueChanged<String?> onTap) {
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

  String _statusLabel(String s) => switch (s) {
        'pending' => 'Sent',
        'in_progress' => 'Processing',
        'resolved' => 'Resolved',
        _ => s,
      };
}

class _AdminRow extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;
  const _AdminRow({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = ReportCategory.fromApi(report.category);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
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
                        errorBuilder: (_, __, ___) => _thumbFallback(cat.icon, cat.tileBg),
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
                        Text(report.reportId,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(width: 8),
                        StatusBadge(report.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.title.isNotEmpty ? report.title : cat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.reporterName.isEmpty ? '-' : report.reporterName}'
                      '${report.reporterPhone.isNotEmpty ? ' · ${report.reporterPhone}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
                    _date(report.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
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

  String _date(DateTime d) {
    final local = d.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
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
      color: Colors.white,
      padding: const EdgeInsets.all(12),
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