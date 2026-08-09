// RecentReportTile — one row in the "Recent Reports" list on the home
// screen. Renders the report's photo thumbnail, title/address, and
// status badge. Supports swipe-to-delete via the onDelete callback.
import 'package:flutter/material.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../data/models/report.dart';
import '../../reports/report_detail_screen.dart';
import '../../widgets/animations.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/report_thumbnail.dart';
import '../../widgets/status_badge.dart';

class RecentReportTile extends StatelessWidget {
  final Report report;
  final Future<bool> Function() onDelete;
  const RecentReportTile({
    super.key,
    required this.report,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = reportDisplayTitle(report, context);
    final cat = ReportCategory.fromApi(report.category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        // A2: expose the swipe-to-delete affordance to screen readers.
        child: Semantics(
          label: title,
          hint: context.t('home.delete_swipe_hint'),
          container: true,
          child: Dismissible(
          key: ValueKey('home-tile-${report.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => onDelete(),
          onDismissed: (_) {},
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
                instantRoute(ReportDetailScreen(reportId: report.id))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                // Ticket stub: a category-coloured bar along the leading
                // edge carries the category.
                border: Border(
                  left: BorderSide(color: cat.tint, width: 3),
                  top: const BorderSide(color: AppColors.border),
                  right: const BorderSide(color: AppColors.border),
                  bottom: const BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Hero(
                    tag: 'report-icon-${report.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: ReportThumbnail(report: report),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reportDisplayTitle(report, context),
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
      ),
    );
  }
}
