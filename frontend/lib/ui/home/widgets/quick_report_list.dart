// QuickReportList — the three illustrated category cards shown on the
// home screen below the "Report an Issue" hero. Tapping a card opens
// the Submit Report screen with the category pre-filled. Illustrations
// and pastel tile backgrounds come from the Claude Design handoff
// (Quick Report Icons v2 — photo-faithful) and are sourced from
// [ReportCategory].
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme.dart';
import '../../reports/submit_report_screen.dart';
import '../../widgets/animations.dart';
import '../../widgets/category_icon.dart';

class QuickReportList extends StatelessWidget {
  const QuickReportList({super.key});

  @override
  Widget build(BuildContext context) {
    final items = ReportCategory.userSelectable
        .where((c) => c.svgAsset != null && c.quickSubtitle != null)
        .toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(items.length, (i) {
          final c = items[i];
          return FadeSlideIn(
            delay: Duration(milliseconds: 360 + i * 60),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressableScale(
                onTap: () => Navigator.of(context).push(
                  fadeSlideRoute(SubmitReportScreen(initialCategory: c.apiValue)),
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
                          color: c.tileBg,
                          padding: const EdgeInsets.all(6),
                          child: SvgPicture.asset(
                            c.svgAsset!,
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
                              c.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.quickSubtitle!,
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
