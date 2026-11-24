// FR-12: tapping a notification opens the report it is about. FirebaseService
// forwards every tap path (tray tap in background, cold start, local
// notification) to ReportEvents.requestOpen; the citizen shell must turn that
// into a ReportDetailScreen for the right report — both when the shell is
// already showing and when the tap launched the app (request made before the
// shell existed).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balaghjo/core/locale_state.dart';
import 'package:balaghjo/core/report_events.dart';
import 'package:balaghjo/core/route_observer.dart';
import 'package:balaghjo/state/auth_state.dart';
import 'package:balaghjo/ui/home/main_shell.dart';
import 'package:balaghjo/ui/reports/report_detail_screen.dart';

Widget _app() => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>.value(value: AuthState()),
        ChangeNotifierProvider<LocaleState>.value(value: LocaleState()),
      ],
      child: MaterialApp(
        navigatorObservers: [appRouteObserver],
        home: const MainShell(),
      ),
    );

String? _openedReportId(WidgetTester tester) {
  final finder = find.byType(ReportDetailScreen);
  if (finder.evaluate().isEmpty) return null;
  return tester.widget<ReportDetailScreen>(finder).reportId;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReportEvents.openRequested.value = null;
  });

  testWidgets('a notification tapped while the app is open opens its report',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(_openedReportId(tester), isNull);

    ReportEvents.requestOpen('RPT-0007');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_openedReportId(tester), 'RPT-0007');
    expect(ReportEvents.openRequested.value, isNull,
        reason: 'the request is consumed so it is not reopened later');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a notification that launched the app opens its report',
      (tester) async {
    // Cold start: the tap is recorded before the shell is built.
    ReportEvents.requestOpen('RPT-0008');

    await tester.pumpWidget(_app());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(_openedReportId(tester), 'RPT-0008');

    await tester.pumpWidget(const SizedBox());
  });
}
