// AdminMapScreen — FR-19 for municipality staff: the dashboard's Map tab.
//
// Same map as the citizen app (category pins, clustering above 50 pins,
// legend, status/category filters), but opening a report goes to the admin
// detail screen, where staff can review the photo/GPS and update the status.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_errors.dart';
import '../../core/locale_state.dart';
import '../../core/strings.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../reports/reports_map_screen.dart';
import '../widgets/animations.dart';
import 'admin_report_detail_screen.dart';

class AdminMapScreen extends StatelessWidget {
  const AdminMapScreen({super.key});

  // Map pins carry only the summary fields; load the full report (photo,
  // history, reporter) before opening the admin detail view.
  static Future<void> _open(BuildContext context, Report summary) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final failedMsg = AppStrings.ofLocaleState(
        context.read<LocaleState>(), 'map.open_failed');
    try {
      final full = await ReportApi().get(summary.id);
      await navigator.push(instantRoute(AdminReportDetailScreen(report: full)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$failedMsg: ${cleanErrorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const ReportsMapView(onOpenReport: _open);
  }
}
