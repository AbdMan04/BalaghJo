// MyReportsRow — one row in the My Reports list. Shows the report
// photo thumbnail, title/status badge, submission date, and a chevron.
// Wrapped in a Dismissible for swipe-to-delete with a confirmation
// callback supplied by the parent screen.
import 'package:flutter/material.dart';
import '../../../core/date_format.dart';
import '../../../core/strings.dart';
import '../../../core/theme.dart';
import '../../../data/models/report.dart';
import '../../widgets/animations.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/report_thumbnail.dart';
import '../../widgets/status_badge.dart';
import '../report_detail_screen.dart';

class MyReportsRow extends StatelessWidget {
  final Report report;
  final Future<bool> Function() onDelete;
  const MyReportsRow({
    super.key,
    required this.report,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = reportDisplayTitle(report, context);
    final cat = ReportCategory.fromApi(report.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        // A2: announce the swipe-to-delete affordance to screen readers;
        // without this the Dismissible gesture is invisible to TalkBack/VoiceOver.
        child: Semantics(
          label: title,
          hint: context.t('home.delete_swipe_hint'),
          container: true,
          child: Dismissible(
            key: ValueKey('my-reports-row-${report.id}'),
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
                  const Icon(Icons.delete_outline,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(context.t('home.delete_swipe_label'),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            child: PressableScale(
              onTap: () => Navigator.of(context)
                  .push(instantRoute(ReportDetailScreen(reportId: report.id))),
              child: Container(
                padding: const EdgeInsets.all(14),
                // The outer ClipRRect provides the rounded corners, so the
                // card itself must NOT combine borderRadius with the
                // non-uniform Border below — that asserts during paint().
                decoration: BoxDecoration(
                  color: Colors.white,
                  // Ticket stub: category-coloured bar along the leading edge
                  // carries the category; the report ID labels the stub.
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
                            report.reportId,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: cat.tint,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reportDisplayTitle(report, context),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              StatusBadge(report.status),
                              const SizedBox(width: 8),
                              Text(formatDate(report.createdAt),
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11)),
                            ],
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
        ),
      ),
    );
  }
}
