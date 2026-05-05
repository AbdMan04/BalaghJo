import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models/report.dart';

class StatusBadge extends StatelessWidget {
  final ReportStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      ReportStatus.pending => (const Color(0xFFE0EAFF), AppColors.blue),
      ReportStatus.inProgress => (const Color(0xFFFFEDD5), AppColors.warning),
      ReportStatus.resolved => (const Color(0xFFDCFCE7), AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}
