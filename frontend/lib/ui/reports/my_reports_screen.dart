import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  String? _filter;
  bool _newestFirst = true;
  late Future<List<Report>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Report>> _load() async {
    final list = await _api.list(status: _filter);
    list.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  void _setFilter(String? f) {
    setState(() {
      _filter = f;
      _future = _load();
    });
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
              const Text('Sort by',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              RadioListTile<bool>(
                value: true,
                groupValue: _newestFirst,
                title: const Text('Newest first'),
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
                title: const Text('Oldest first'),
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
        title: const Text('My Reports', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          PressableScale(
            onTap: _openSortSheet,
            child: const Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.tune)),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _chip('All', null),
                _chip('Sent', 'pending'),
                _chip('Processing', 'in_progress'),
                _chip('Resolved', 'resolved'),
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
                final reports = snap.data ?? [];
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text('No reports yet',
                            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700)),
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
                    color: AppColors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(iconForCategory(report.category), color: AppColors.navy),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.title.isNotEmpty ? report.title : labelForCategory(report.category),
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
