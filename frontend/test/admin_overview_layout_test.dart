// Widget tests for the admin overview dashboard: it must render every block
// (hero band, secondary stat cards, trend chart, category breakdown) without
// a RenderFlex overflow at phone, tablet and desktop widths, in both the
// default English and Arabic (RTL) locales. The screen loads its stats
// through the injected loadStats seam, so no network is touched.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balaghjo/core/locale_state.dart';
import 'package:balaghjo/core/theme.dart';
import 'package:balaghjo/data/models/admin_stats.dart';
import 'package:balaghjo/ui/admin/admin_overview_screen.dart';

AdminStats _stats() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return AdminStats(
    total: 482,
    pending: 96,
    inProgress: 41,
    resolved: 345,
    active: 41,
    users: 1230,
    categories: const [
      CategoryCount(category: 'pothole', count: 210),
      CategoryCount(category: 'waste', count: 118),
      CategoryCount(category: 'lighting', count: 87),
      CategoryCount(category: 'other', count: 67),
    ],
    daily: [
      for (var i = 13; i >= 0; i--)
        DailyCount(
          date: today.subtract(Duration(days: i)),
          count: (i * 7) % 40,
        ),
    ],
  );
}

Widget _wrap(LocaleState state) => ChangeNotifierProvider<LocaleState>.value(
      value: state,
      child: MaterialApp(
        theme: buildAppTheme(),
        locale: state.locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: AdminOverviewScreen(loadStats: () async => _stats())),
      ),
    );

void main() {
  Future<void> pumpOverview(WidgetTester tester, double width,
      {LocaleState? state}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap(state ?? LocaleState()));
    // Let the initial RemoteView load and the entrance animations settle.
    await tester.pump();
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 768.0, 1280.0, 1600.0]) {
    testWidgets('renders every block without overflow at ${width.toInt()}px',
        (tester) async {
      await pumpOverview(tester, width);

      expect(tester.takeException(), isNull);
      expect(find.text('482'), findsOneWidget);
      expect(find.text('72'), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);

      // The category breakdown sits below the fold at narrow widths; scroll
      // to it so its rows are built and any overflow there surfaces too.
      await tester.scrollUntilVisible(find.text('Pothole'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Pothole'), findsOneWidget);

      // Unmount so the RouteAwarePolling timer is cancelled before the
      // test's pending-timer check.
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('renders without overflow in Arabic (RTL)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = LocaleState();
    await state.setLocale(const Locale('ar'));
    await pumpOverview(tester, 768, state: state);

    expect(tester.takeException(), isNull);
    expect(find.byType(AdminOverviewScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
