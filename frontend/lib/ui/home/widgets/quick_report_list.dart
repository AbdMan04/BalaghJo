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
    final items = ReportCategory.userSelectable.toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i += 2) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Card(category: items[i], delayMs: 360)),
                if (i + 1 < items.length) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _Card(category: items[i + 1], delayMs: 420)),
                ],
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
                  child: category.svgAsset != null
                      ? SvgPicture.asset(category.svgAsset!, fit: BoxFit.contain)
                      : Icon(category.icon, color: category.tint, size: 22),
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
                      category.quickSubtitle ?? category.labelAr,
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
