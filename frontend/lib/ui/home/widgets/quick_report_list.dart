// QuickReportList — the three illustrated category cards shown on the
// home screen below the "Report an Issue" hero. Tapping a card opens
// the Submit Report screen with the category pre-filled. Illustrations
// and pastel tile backgrounds come from the Claude Design handoff
// (Quick Report Icons v2 — photo-faithful).
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../reports/submit_report_screen.dart';
import '../../widgets/animations.dart';

class QuickReportList extends StatelessWidget {
  const QuickReportList({super.key});

  static const _tileBg = {
    'pothole': AppColors.tilePothole,
    'waste': AppColors.tileWaste,
    'lighting': AppColors.tileLighting,
  };

  static const _items = [
    ('pothole', 'cat.pothole', 'home.quick_pothole_sub'),
    ('waste', 'cat.waste', 'home.quick_waste_sub'),
    ('lighting', 'cat.lighting', 'home.quick_lighting_sub'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          return FadeSlideIn(
            delay: Duration(milliseconds: 360 + i * 60),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressableScale(
                onTap: () => Navigator.of(context).push(
                  fadeSlideRoute(SubmitReportScreen(initialCategory: item.$1)),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 60,
                          height: 60,
                          color: _tileBg[item.$1] ?? AppColors.surface,
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture.asset(
                            'assets/icons/quick_report/${item.$1}.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t(item.$2),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.t(item.$3),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
