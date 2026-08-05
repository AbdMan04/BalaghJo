// Shared delete-with-undo flow used by Home (recent reports) and My
// Reports. Single source of truth for the confirm dialog, the 3s undo
// snackbar, and the delayed API delete — so a bug fix here applies to
// both screens instead of drifting across two copies.
import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import 'category_icon.dart';

/// Runs the full delete flow and returns true when the user confirmed.
/// The report is not deleted immediately: it sits in [pendingIds] for the
/// 3s snackbar window (undo removes it, and the delete only fires after
/// the snackbar closes if the id is still pending). [onDeleted] is called
/// after a successful API delete so the caller can refresh its list.
Future<bool> runReportDeleteFlow({
  required BuildContext context,
  required ReportApi api,
  required Report report,
  required Set<String> pendingIds,
  required void Function(VoidCallback fn) setState,
  required Future<void> Function() onDeleted,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg)),
      title: Text(ctx.t('home.delete_title'),
          style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(
        '${ctx.t('home.delete_body_prefix')}'
        '${reportDisplayTitle(report, ctx)}'
        '${ctx.t('home.delete_body_suffix')}',
        style: const TextStyle(color: AppColors.textMuted, height: 1.4),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(ctx.t('common.cancel'),
                      style: const TextStyle(
                          color: AppColors.navy, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm)),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  child: Text(ctx.t('common.delete'),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  if (!context.mounted) return false;

  setState(() => pendingIds.add(report.id));
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  final controller = messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md)),
      duration: const Duration(seconds: 3),
      content: Text(context.t('home.deleted_toast'),
          style: const TextStyle(color: Colors.white)),
      action: SnackBarAction(
        label: context.t('common.undo'),
        textColor: Colors.white,
        onPressed: () {
          if (!context.mounted) return;
          setState(() => pendingIds.remove(report.id));
        },
      ),
    ),
  );
  // Guarantee auto-dismiss at 3s even if the framework's snackbar timer
  // is interrupted; controller.closed still fires so the delete below runs.
  Future.delayed(const Duration(seconds: 3), () {
    if (context.mounted) messenger.hideCurrentSnackBar();
  });
  controller.closed.then((_) async {
    if (!context.mounted) return;
    if (!pendingIds.contains(report.id)) return;
    try {
      await api.delete(report.id);
      if (!context.mounted) return;
      pendingIds.remove(report.id);
      await onDeleted();
    } catch (e) {
      if (!context.mounted) return;
      setState(() => pendingIds.remove(report.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  });
  return true;
}
