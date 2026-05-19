// QuickReportList — the three illustrated category cards shown on the
// home screen below the "Report an Issue" hero. Laid out as a 2+1
// grid: the first two categories share the top row, the third sits
// centered below at the same card size. Tapping a card opens the
// Submit Report screen with the category pre-filled. Illustrations
// and pastel tile backgrounds come from [ReportCategory], which is
// populated from the Claude Design handoff (Quick Report Icons v2 —
// photo-faithful).
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
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          if (items.length >= 2)
            Row(
              children: [
                Expanded(child: _Card(category: items[0], delayMs: 360)),
                const SizedBox(width: 10),
                Expanded(child: _Card(category: items[1], delayMs: 420)),
              ],
            ),
          if (items.length >= 3) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Expanded(flex: 2, child: _Card(category: items[2], delayMs: 480)),
                const Spacer(),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final ReportCategory category;
  final int delayMs;
  const _Card({required this.category, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      delay: Duration(milliseconds: delayMs),
      child: PressableScale(
        onTap: () => Navigator.of(context).push(
          fadeSlideRoute(SubmitReportScreen(initialCategory: category.apiValue)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 48,
                  color: category.tileBg,
                  padding: const EdgeInsets.all(5),
                  child: SvgPicture.asset(category.svgAsset!, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.quickSubtitle!,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
