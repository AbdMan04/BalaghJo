// StatusBadge — FR-10: status shown on every report card and detail
// screen, colour-coded and labelled in Arabic and English. Text colours
// were picked to hold a >= 4.5:1 contrast ratio against the badge tint:
//   pending    #1B4FD8 on #E0EAFF  -> 5.5:1
//   in progress #92400E on #FFEDD5 -> 6.2:1
//   resolved   #166534 on #DCFCE7  -> 6.5:1
import 'package:flutter/material.dart';
import '../../data/models/report.dart';

class StatusBadge extends StatelessWidget {
  final ReportStatus status;
  final bool large;
  const StatusBadge(this.status, {super.key, this.large = false});

  static const _fgPending = Color(0xFF1B4FD8);
  static const _fgInProgress = Color(0xFF92400E);
  static const _fgResolved = Color(0xFF166534);

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (status) {
      ReportStatus.pending => (
        const Color(0xFFE0EAFF),
        _fgPending,
        Icons.access_time_rounded,
      ),
      ReportStatus.inProgress => (
        const Color(0xFFFFEDD5),
        _fgInProgress,
        Icons.sync_rounded,
      ),
      ReportStatus.resolved => (
        const Color(0xFFDCFCE7),
        _fgResolved,
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
            status.labelAr,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            ' · ${status.label}',
            style: TextStyle(
              color: fg,
              fontSize: fontSize - 1,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
