// HomeStatsHeader — the flat asphalt band at the top of the home screen
// with the three live stats (Total / Resolved / Active) fed by the
// report-summary future. Civic notice-board treatment: numbers sit directly
// on the band, separated by hairlines, no inner card or shadow.
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
      color: AppColors.ink,
      padding: const EdgeInsets.fromLTRB(20, 44, 20, 26),
      child: FutureBuilder<ReportSummary>(
        future: future,
        builder: (_, snap) {
          final s = snap.data;
          return Row(
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
          );
        },
      ),
    );
  }

  Widget _stat(IconData icon, String label, int value) => Expanded(
        child: Column(
          children: [
            Icon(icon, size: 16, color: AppColors.safety),
            const SizedBox(height: 4),
            AnimatedCounter(
              value: value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.1),
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

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);
}
