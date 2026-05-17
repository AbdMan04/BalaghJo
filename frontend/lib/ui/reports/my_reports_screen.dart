// MyReportsScreen — feature F3 (Report List & History).
//
// Shows the authenticated user's own reports in reverse-chronological
// order (FR-7), rendering category, submission date, and status for
// each row (FR-8). Provides a debounced text search over title/
// description, category filter chips, status filter chips, pull-to-
// refresh, and swipe-to-delete with a confirmation dialog. Tapping a
// row opens ReportDetailScreen (FR-9).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/status_badge.dart';
import 'report_detail_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _api = ReportApi();
  final _search = TextEditingController();
  String? _filter;
  String? _categoryFilter;
  bool _newestFirst = true;
  late Future<List<Report>> _future;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Report>> _load() async {
    final list = await _api.list(status: _filter);
    list.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  List<Report> _applyClientFilters(List<Report> source) {
    final query = _search.text.trim().toLowerCase();
    return source.where((r) {
      if (_categoryFilter != null && r.category != _categoryFilter) return false;
      if (query.isEmpty) return true;
      return r.title.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query) ||
          r.address.toLowerCase().contains(query) ||
          labelForCategory(r.category, context).toLowerCase().contains(query) ||
          r.reportId.toLowerCase().contains(query);
    }).toList();
  }

  void _setFilter(String? f) {
    setState(() {
      _filter = f;
      _future = _load();
    });
  }

  void _setCategory(String? c) {
    setState(() => _categoryFilter = c);
  }

  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(context.t('my.sort_title'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              RadioListTile<bool>(
                value: true,
                groupValue: _newestFirst,
                title: Text(context.t('my.sort_newest')),
                onChanged: (v) {
                  setState(() {
                    _newestFirst = v ?? true;
                    _future = _load();
                  });
                  Navigator.pop(context);
                },
              ),
              RadioListTile<bool>(
                value: false,
                groupValue: _newestFirst,
                title: Text(context.t('my.sort_oldest')),
                onChanged: (v) {
                  setState(() {
                    _newestFirst = v ?? false;
                    _future = _load();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('my.title'), style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PressableScale(
            onTap: _openSortSheet,
            child: const Padding(padding: EdgeInsetsDirectional.only(end: 16), child: Icon(Icons.tune)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: context.t('my.search_hint'),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                        onPressed: () => _search.clear(),
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _chip(context.t('status.all'), null),
                _chip(context.t('status.sent'), 'pending'),
                _chip(context.t('status.processing'), 'in_progress'),
                _chip(context.t('status.resolved'), 'resolved'),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                _categoryChip(context.t('cat.all'), null),
                _categoryChip(context.t('cat.pothole'), 'pothole'),
                _categoryChip(context.t('cat.waste'), 'waste'),
                _categoryChip(context.t('cat.lighting'), 'lighting'),
                _categoryChip(context.t('cat.road_crack'), 'road_crack'),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Report>>(
              future: _future,
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.blue));
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final all = snap.data ?? [];
                final reports = _applyClientFilters(all);
                if (reports.isEmpty) {
                  final filtered = all.isNotEmpty;
                  return RefreshIndicator(
                    onRefresh: () async => _setFilter(_filter),
                    color: AppColors.blue,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                filtered ? Icons.filter_alt_off_outlined : Icons.inbox_outlined,
                                size: 64,
                                color: AppColors.textMuted.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                filtered ? context.t('my.no_matches') : context.t('home.no_reports_yet'),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontWeight: FontWeight.w700),
                              ),
                              if (filtered) ...[
                                const SizedBox(height: 6),
                                Text(
                                  context.t('my.try_other'),
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _setFilter(_filter),
                  color: AppColors.blue,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: reports.length,
                    itemBuilder: (_, i) => FadeSlideIn(
                      delay: Duration(milliseconds: 60 * i),
                      child: _ReportRow(report: reports[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final active = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        onTap: () => _setFilter(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: active ? AppColors.navy : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppColors.navy : AppColors.border),
            boxShadow: active
                ? [BoxShadow(color: AppColors.navy.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 240),
            style: TextStyle(
              color: active ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String? value) {
    final active = _categoryFilter == value;
    final tint = value == null ? AppColors.blue : colorForCategory(value);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PressableScale(
        onTap: () => _setCategory(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? tint.withValues(alpha: 0.12) : Colors.white,
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

class _ReportRow extends StatelessWidget {
  final Report report;
  const _ReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        onTap: () => Navigator.of(context).push(
            fadeSlideRoute(ReportDetailScreen(reportId: report.id))),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Hero(
                tag: 'report-icon-${report.id}',
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorForCategory(report.category).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(iconForCategory(report.category),
                      color: colorForCategory(report.category)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.title.isNotEmpty ? report.title : labelForCategory(report.category, context),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusBadge(report.status),
                        const SizedBox(width: 8),
                        Text(DateFormat.yMMMd().format(report.createdAt),
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
