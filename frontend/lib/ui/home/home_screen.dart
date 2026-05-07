import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../../state/auth_state.dart';
import '../reports/report_detail_screen.dart';
import '../reports/reports_map_screen.dart';
import '../reports/submit_report_screen.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/status_badge.dart';
import 'main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ReportApi();
  Future<ReportSummary>? _future;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        title: Text(context.t('home.delete_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${context.t('home.delete_body_prefix')}${r.title.isNotEmpty ? r.title : r.reportId}${context.t('home.delete_body_suffix')}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
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
      await _refresh();
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

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.blue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.navy, Color(0xFF112A55), AppColors.blue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeSlideIn(
                          child: Text(context.t('home.welcome'),
                              style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        ),
                        const SizedBox(height: 4),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 100),
                          child: Text(user?.firstName ?? 'Citizen',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(height: 20),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 200),
                          child: FutureBuilder<ReportSummary>(
                            future: _future,
                            builder: (_, snap) {
                              final s = snap.data;
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Row(
                                  children: [
                                    _stat(context.t('home.stat_total'), s?.total ?? 0),
                                    _divider(),
                                    _stat(context.t('home.stat_resolved'), s?.resolved ?? 0),
                                    _divider(),
                                    _stat(context.t('home.stat_active'), s?.active ?? 0),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 30,
                    right: -30,
                    child: GradientBlob(color: AppColors.sky.withValues(alpha: 0.5), size: 180),
                  ),
                ],
              ),
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
                    child: Text(context.t('home.quick_report'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _CategoriesGrid(),
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
                        children: List.generate(3, (i) => const _SkeletonTile()),
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
                  final reports = snap.data?.recent ?? [];
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
                        child: _ReportTile(
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

  Widget _stat(String label, int value) => Expanded(
        child: Column(
          children: [
            AnimatedCounter(
              value: value,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 32, color: Colors.white24);
}

class _ReportTile extends StatelessWidget {
  final Report report;
  final Future<bool> Function() onDelete;
  const _ReportTile({required this.report, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Dismissible(
          key: ValueKey('home-tile-${report.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => onDelete(),
          background: Container(
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(context.t('home.delete_swipe_label'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
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
                        Text(
                          report.title.isNotEmpty ? report.title : labelForCategory(report.category, context),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          report.address.isNotEmpty ? report.address : 'Location pending',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        StatusBadge(report.status),
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
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SkeletonBox(
              height: 44,
              width: 44,
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 12, width: 160),
                  SizedBox(height: 8),
                  SkeletonBox(height: 10, width: 110),
                  SizedBox(height: 10),
                  SkeletonBox(
                    height: 16,
                    width: 70,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
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

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid();

  static const _items = [
    ('pothole', 'cat.pothole', Icons.warning_amber_rounded),
    ('waste', 'cat.waste', Icons.delete_outline),
    ('lighting', 'cat.lighting', Icons.lightbulb_outline),
    ('road_crack', 'cat.road_crack', Icons.alt_route),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final tint = colorForCategory(item.$1);
          return FadeSlideIn(
            delay: Duration(milliseconds: 360 + i * 60),
            child: PressableScale(
              onTap: () => Navigator.of(context).push(
                fadeSlideRoute(SubmitReportScreen(initialCategory: item.$1)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(item.$3, color: tint, size: 22),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t(item.$2),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
