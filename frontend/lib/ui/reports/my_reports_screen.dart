// MyReportsScreen — feature F3 (Report List & History).
//
// Shows the authenticated user's own reports in reverse-chronological
// order (FR-7), rendering category, submission date, and status for
// each row (FR-8). Provides a debounced text search over title/
// description, category filter chips, status filter chips, pull-to-
// refresh, and swipe-to-delete with a confirmation dialog. Tapping a
// row opens ReportDetailScreen (FR-9).
import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import 'widgets/my_reports_row.dart';
import 'widgets/report_filter_chips.dart';

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

  Future<bool> _deleteReport(Report r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text(context.t('home.delete_title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${context.t('home.delete_body_prefix')}${r.title.isNotEmpty ? r.title : r.reportId}${context.t('home.delete_body_suffix')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('common.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    try {
      await _api.delete(r.id);
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          content: Text(context.t('home.deleted_toast')),
        ),
      );
      setState(() => _future = _load());
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
      return false;
    }
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

  void _selectSort(bool newestFirst) {
    setState(() {
      _newestFirst = newestFirst;
      _future = _load();
    });
    Navigator.pop(context);
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('my.sort_newest')),
                trailing: _newestFirst ? const Icon(Icons.check, color: AppColors.blue) : null,
                onTap: () => _selectSort(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.t('my.sort_oldest')),
                trailing: !_newestFirst ? const Icon(Icons.check, color: AppColors.blue) : null,
                onTap: () => _selectSort(false),
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
                StatusFilterChip(label: context.t('status.all'), active: _filter == null, onTap: () => _setFilter(null)),
                StatusFilterChip(label: context.t('status.sent'), active: _filter == 'pending', onTap: () => _setFilter('pending')),
                StatusFilterChip(label: context.t('status.processing'), active: _filter == 'in_progress', onTap: () => _setFilter('in_progress')),
                StatusFilterChip(label: context.t('status.resolved'), active: _filter == 'resolved', onTap: () => _setFilter('resolved')),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                CategoryFilterChip(label: context.t('cat.all'), value: null, active: _categoryFilter == null, onTap: () => _setCategory(null)),
                CategoryFilterChip(label: context.t('cat.pothole'), value: 'pothole', active: _categoryFilter == 'pothole', onTap: () => _setCategory('pothole')),
                CategoryFilterChip(label: context.t('cat.waste'), value: 'waste', active: _categoryFilter == 'waste', onTap: () => _setCategory('waste')),
                CategoryFilterChip(label: context.t('cat.lighting'), value: 'lighting', active: _categoryFilter == 'lighting', onTap: () => _setCategory('lighting')),
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
                      child: MyReportsRow(
                        report: reports[i],
                        onDelete: () => _deleteReport(reports[i]),
                      ),
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
}
