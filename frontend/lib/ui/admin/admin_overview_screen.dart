// AdminOverviewScreen — dashboard landing tab. Renders the admin-wide
// aggregates from GET /api/admin/stats: live stat cards (total / active /
// resolved / pending / users), a category breakdown, and a 14-day report
// trend chart. Trend gaps are filled with zeroes so the axis is stable.
import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/admin_api.dart';
import '../../data/models/admin_stats.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/remote_view.dart';

class AdminOverviewScreen extends StatefulWidget {
  const AdminOverviewScreen({super.key});

  @override
  State<AdminOverviewScreen> createState() => _AdminOverviewScreenState();
}

class _AdminOverviewScreenState extends State<AdminOverviewScreen> {
  final _api = AdminApi();

  @override
  Widget build(BuildContext context) {
    return RemoteView<AdminStats>(
      load: _api.stats,
      builder: (context, s) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statCard(context, Icons.description_outlined, context.t('admin.stat_total'), s.total, AppColors.navy),
              _statCard(context, Icons.pending_actions_outlined, context.t('admin.stat_active'), s.active, AppColors.warning),
              _statCard(context, Icons.check_circle_outline, context.t('admin.stat_resolved'), s.resolved, AppColors.success),
              _statCard(context, Icons.schedule, context.t('admin.stat_pending'), s.pending, AppColors.blue),
              _statCard(context, Icons.people_outline, context.t('admin.stat_users'), s.users, AppColors.calmBlue),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, context.t('admin.trend_title')),
          const SizedBox(height: 12),
          _TrendChart(daily: s.daily),
          const SizedBox(height: 24),
          _sectionTitle(context, context.t('admin.by_category')),
          const SizedBox(height: 12),
          _CategoryBreakdown(categories: s.categories),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      );

  Widget _statCard(BuildContext context, IconData icon, String label, int value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          AnimatedCounter(
            value: value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  final List<CategoryCount> categories;
  const _CategoryBreakdown({required this.categories});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Text(context.t('admin.no_reports'));
    }
    final max = categories.map((c) => c.count).fold<int>(1, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      ReportCategory.fromApi(c.category).label,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Container(height: 10, color: AppColors.surface),
                          FractionallySizedBox(
                            widthFactor: max == 0 ? 0 : c.count / max,
                            child: Container(
                              height: 10,
                              color: ReportCategory.fromApi(c.category).tint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(
                      '${c.count}',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<DailyCount> daily;
  const _TrendChart({required this.daily});

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final d in daily) _key(d.date): d.count};
    final now = DateTime.now();
    final days = <MapEntry<String, int>>[];
    for (int i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      days.add(MapEntry(_key(day), byDate[_key(day)] ?? 0));
    }
    final max = days.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in days)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${entry.value}',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Container(
                    height: 90 * (entry.value / max),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: entry.value == 0 ? AppColors.border : AppColors.ink,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${entry.key.substring(8)}/${entry.key.substring(5, 7)}',
                      style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
