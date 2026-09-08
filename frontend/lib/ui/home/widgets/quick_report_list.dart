// QuickReportList — the three category cards shown on the home screen
// below the "Report an Issue" hero. Laid out as a 2+1 grid: the first
// two categories share the top row, the third sits centered below at the
// same card size. Tapping a card opens the Submit Report screen with the
// category pre-filled. Real photos and pastel tile backgrounds come from
// [ReportCategory], so the user sees exactly what a category looks like
// before choosing it.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../core/locale_state.dart';
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
          pageRoute(SubmitReportScreen(initialCategory: category.apiValue)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 64,
                  height: 64,
                  color: category.tileBg,
                  child: category.photoAsset != null
                      ? Image.asset(category.photoAsset!,
                          fit: BoxFit.cover)
                      : Center(
                          child: Icon(category.icon,
                              color: category.tint, size: 22),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CardLabel(category: category),
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

// Renders the category label so it never gets cut off: two-word labels like
// "Broken Light" or "تراكم نفايات" are split so each word sits on its own
// smaller line, stacked on top of the other, instead of being ellipsized
// mid-word. Single-word labels keep the normal one-line size.
class _CardLabel extends StatelessWidget {
  final ReportCategory category;
  const _CardLabel({required this.category});

  @override
  Widget build(BuildContext context) {
    final label =
        category.localizedLabel(context.watch<LocaleState>().isArabic);
    final words = label.split(' ');
    final isStacked = words.length > 1;
    return Text(
      isStacked ? words.join('\n') : label,
      textAlign: isStacked ? TextAlign.center : null,
      style: TextStyle(
        fontSize: isStacked ? 11 : 13,
        height: isStacked ? 1.25 : null,
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
      ),
    );
  }
}
