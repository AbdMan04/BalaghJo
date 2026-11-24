// Widget tests for the responsive AdminShell: below the phone breakpoint the
// dashboard swaps the sidebar for a top app bar + bottom navigation so the
// web dashboard stays consistent in a phone browser; wider layouts keep the
// operations-board sidebar. Screens hit the network via RemoteView, which
// errors out in tests, but the shell chrome itself must render without
// overflow at every size.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balaghjo/core/locale_state.dart';
import 'package:balaghjo/core/strings.dart';
import 'package:balaghjo/state/auth_state.dart';
import 'package:balaghjo/ui/admin/admin_map_screen.dart';
import 'package:balaghjo/ui/admin/admin_shell.dart';
import 'package:balaghjo/ui/reports/widgets/report_cluster_layer.dart';

const _sidebar = Key('admin_sidebar');
const _bottomNav = Key('admin_bottom_nav');

Widget _wrap() => MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthState>.value(value: AuthState()),
        ChangeNotifierProvider<LocaleState>.value(value: LocaleState()),
      ],
      child: const MaterialApp(home: AdminShell()),
    );

Future<void> _pump(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 820));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_wrap());
  // Let the initial RemoteView loads (which fail fast in tests) land.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('phone widths use the bottom nav and render without overflow',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    for (final width in [320.0, 390.0, 600.0]) {
      await _pump(tester, width);

      expect(find.byKey(_bottomNav), findsOneWidget);
      expect(find.byKey(_sidebar), findsNothing);
      expect(tester.takeException(), isNull);

      // Unmount so RouteAwarePolling timers are cancelled before the next
      // iteration's pending-timer check.
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('desktop width keeps the sidebar and has no bottom nav',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, 1280);

    expect(find.byKey(_sidebar), findsOneWidget);
    expect(find.byKey(_bottomNav), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Map tab is only built once an admin opens it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Map tiles can't load offline; flutter_map reports each failure via
    // debugPrint. Silence that noise for this test only.
    // Restored inside the body: Flutter checks debug vars before tear-downs.
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      await _pump(tester, 1280);

      // Not built on dashboard load (keeps NFR-8's first load lean).
      expect(find.byType(AdminMapScreen), findsNothing);

      await tester.tap(find.descendant(
        of: find.byKey(_sidebar),
        matching: find.byIcon(Icons.map_outlined),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AdminMapScreen), findsOneWidget);
      expect(find.byType(MapLegend), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    } finally {
      debugPrint = originalDebugPrint;
    }
  });

  testWidgets('tapping a bottom nav item switches the section title',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final locale = LocaleState();
    final reportsTitle = AppStrings.ofLocaleState(locale, 'admin.nav_reports');

    await _pump(tester, 390);

    final reportsTab = find.descendant(
      of: find.byKey(_bottomNav),
      matching: find.byIcon(Icons.assignment_outlined),
    );
    expect(reportsTab, findsOneWidget);
    await tester.tap(reportsTab);
    await tester.pump();

    expect(
      find.descendant(
          of: find.byType(AppBar), matching: find.text(reportsTitle)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
