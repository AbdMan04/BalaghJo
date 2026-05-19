import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../reports/reports_map_screen.dart';
import '../widgets/animations.dart';
import 'main_shell.dart';
import 'widgets/home_stats_header.dart';
import 'widgets/quick_report_list.dart';
import 'widgets/recent_report_tile.dart';
import 'widgets/skeleton_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ReportApi();
  Future<ReportSummary>? _future;
  final Set<String> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();
    _future = _api.summary();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _api.summary();
    });
    await _future;
  }

  Future<bool> _deleteReport(Report r) async {
    setState(() => _pendingDeletes.add(r.id));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        duration: const Duration(seconds: 4),
        content: Text(context.t('home.deleted_toast')),
        action: SnackBarAction(
          label: context.t('common.undo'),
          textColor: Colors.white,
          onPressed: () {
            if (!mounted) return;
            setState(() => _pendingDeletes.remove(r.id));
          },
        ),
      ),
    );
    controller.closed.then((_) async {
      if (!mounted) return;
      if (!_pendingDeletes.contains(r.id)) return;
      try {
        await _api.delete(r.id);
        if (!mounted) return;
        _pendingDeletes.remove(r.id);
        await _refresh();
      } catch (e) {
        if (!mounted) return;
        setState(() => _pendingDeletes.remove(r.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              HomeStatsHeader(future: _future),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 280),
                  child: PressableScale(
                    onTap: () => MainShellScope.of(context)?.goTo(1),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.navy, Color(0xFF1E3A8A)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              boxShadow: [
                                BoxShadow(color: AppColors.sky.withValues(alpha: 0.5), blurRadius: 12),
                              ],
                            ),
                            child: const Icon(Icons.add, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.t('home.report_issue'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(context.t('home.report_issue_sub'),
                                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 320),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t('home.quick_report'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(context.t('home.quick_report_sub'),
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const QuickReportList(),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 600),
                  child: PressableScale(
                    onTap: () => Navigator.of(context).push(
                      fadeSlideRoute(const ReportsMapScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.blue, AppColors.sky],
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.blue.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.map_outlined, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.t('home.explore_map'),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(context.t('home.explore_map_sub'),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.t('home.recent_reports'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    GestureDetector(
                      onTap: () => MainShellScope.of(context)?.goTo(2),
                      child: Text(context.t('home.view_all'),
                          style: const TextStyle(color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FutureBuilder<ReportSummary>(
                future: _future,
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: List.generate(3, (i) => const SkeletonTile()),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Failed to load: ${snap.error}',
                          style: const TextStyle(color: AppColors.danger)),
                    );
                  }
                  final reports = (snap.data?.recent ?? [])
                      .where((r) => !_pendingDeletes.contains(r.id))
                      .toList();
                  if (reports.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 56, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text(context.t('home.no_reports_yet'),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(context.t('home.submit_first'),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: List.generate(reports.length, (i) {
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 80 * i),
                        child: RecentReportTile(
                          report: reports[i],
                          onDelete: () => _deleteReport(reports[i]),
                        ),
                      );
                    }),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

}
