// HomeStatsHeader — the blue gradient banner at the top of the home
// screen, containing the three live stats (Total / Resolved / Active)
// fed by the report-summary future. Includes the decorative sky-tinted
// gradient blob in the top-right corner.
import 'package:flutter/material.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../data/api/report_api.dart';
import '../../widgets/animations.dart';

class HomeStatsHeader extends StatelessWidget {
  final Future<ReportSummary>? future;
  const HomeStatsHeader({super.key, required this.future});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            child: FutureBuilder<ReportSummary>(
              future: future,
              builder: (_, snap) {
                final s = snap.data;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      _stat(Icons.description_outlined,
                          context.t('home.stat_total'), s?.total ?? 0),
                      _divider(),
                      _stat(Icons.check_circle_outline,
                          context.t('home.stat_resolved'), s?.resolved ?? 0),
                      _divider(),
                      _stat(Icons.pending_actions_outlined,
                          context.t('home.stat_active'), s?.active ?? 0),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, int value) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(height: 4),
            AnimatedCounter(
              value: value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 32, color: Colors.white24);
}
