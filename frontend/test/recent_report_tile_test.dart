// Widget test for the home-screen RecentReportTile: after the report-ID
// removal it must render the title, address and status badge but never the
// ticket number.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:balaghjo/core/locale_state.dart';
import 'package:balaghjo/data/models/report.dart';
import 'package:balaghjo/ui/home/widgets/recent_report_tile.dart';

Report _report() => Report(
      id: 'r1',
      reportId: 'BAL-000123',
      category: 'pothole',
      title: 'Deep pothole',
      description: 'A large pothole blocking traffic',
      photoUrl: '',
      address: 'Al-Yarmouk St',
      lat: 31.5,
      lng: 35.2,
      status: ReportStatus.inProgress,
      assignedTo: '',
      createdAt: DateTime.now(),
    );

Widget _wrap(Widget child) => ChangeNotifierProvider(
      create: (_) => LocaleState(),
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('shows title, address and status but not the report ID',
      (tester) async {
    await tester.pumpWidget(
      _wrap(RecentReportTile(report: _report(), onDelete: () async => false)),
    );
    await tester.pump();

    expect(find.text('BAL-000123'), findsNothing);
    expect(find.text('Deep pothole'), findsOneWidget);
    expect(find.text('Al-Yarmouk St'), findsOneWidget);
    expect(find.text(' · Processing'), findsOneWidget);
  });

  testWidgets('falls back to the category label when title and address are empty',
      (tester) async {
    final report = _report();
    final untitled = Report(
      id: report.id,
      reportId: report.reportId,
      category: 'waste',
      title: '',
      description: '',
      photoUrl: '',
      address: '',
      lat: 0,
      lng: 0,
      status: ReportStatus.pending,
      assignedTo: '',
      createdAt: report.createdAt,
    );
    await tester.pumpWidget(
      _wrap(RecentReportTile(report: untitled, onDelete: () async => false)),
    );
    await tester.pump();

    expect(find.text('Waste'), findsOneWidget);
    expect(find.text('Location pending'), findsOneWidget);
    expect(find.text(' · Sent'), findsOneWidget);
  });
}
