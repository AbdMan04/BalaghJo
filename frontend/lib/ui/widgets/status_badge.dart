import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../data/models/report.dart';

class StatusBadge extends StatelessWidget {
  final ReportStatus status;
  final bool large;
  const StatusBadge(this.status, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (status) {
      ReportStatus.pending => (
        const Color(0xFFE0EAFF),
        AppColors.blue,
        Icons.access_time_rounded,
      ),
      ReportStatus.inProgress => (
        const Color(0xFFFFEDD5),
        AppColors.warning,
        Icons.sync_rounded,
      ),
      ReportStatus.resolved => (
        const Color(0xFFDCFCE7),
        AppColors.success,
        Icons.check_circle_rounded,
      ),
    };
    final padH = large ? 12.0 : 10.0;
    final padV = large ? 6.0 : 4.0;
    final iconSize = large ? 14.0 : 12.0;
    final fontSize = large ? 12.0 : 11.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: iconSize),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
