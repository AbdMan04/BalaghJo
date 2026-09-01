// Widget test for the dashboard language switch mechanism: tapping the
// Arabic/English PopupMenuButton in the admin header must flip isArabic,
// rebuild every context.t() consumer, and surface the confirmation snackbar.
// Mirrors _LanguageToggle in admin_shell.dart exactly.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:balaghjo/core/locale_state.dart';
import 'package:balaghjo/core/strings.dart';
import 'package:balaghjo/core/theme.dart';

class _ToggleHarness extends StatelessWidget {
  const _ToggleHarness();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleState>();
    final isArabic = locale.isArabic;
    final enLabel = context.t('admin.language_english');
    final arLabel = context.t('admin.language_arabic');
    return PopupMenuButton<String>(
      tooltip: context.t('admin.language_title'),
      initialValue: isArabic ? 'ar' : 'en',
      onSelected: (value) {
        final state = context.read<LocaleState>();
        final target = value == 'ar' ? const Locale('ar') : const Locale('en');
        if (state.locale == target) return;
        state.setLocale(target);
        final msg = AppStrings.ofLocaleState(state, 'admin.language_updated');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(msg),
          ),
        );
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'en',
          child: Row(children: [
            if (!isArabic) const Icon(Icons.check, size: 16),
            const SizedBox(width: 8),
            Text(enLabel),
          ]),
        ),
        PopupMenuItem(
          value: 'ar',
          child: Row(children: [
            if (isArabic) const Icon(Icons.check, size: 16),
            const SizedBox(width: 8),
            Text(arLabel),
          ]),
        ),
      ],
      child: const Text('LANG'),
    );
  }
}

void main() {
  testWidgets('tapping Arabic in the header toggle switches the locale',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = LocaleState();
    await state.bootstrap();

    await tester.pumpWidget(
      ChangeNotifierProvider<LocaleState>.value(
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
          home: Scaffold(
            body: Column(
              children: [
                const _ToggleHarness(),
                Builder(
                  builder: (context) =>
                      Center(child: Text(context.t('admin.badge'))),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final enBadge = AppStrings.ofLocaleState(state, 'admin.badge');
    expect(state.isArabic, isFalse);
    expect(find.text(enBadge), findsOneWidget);

    await tester.tap(find.text('LANG'));
    await tester.pumpAndSettle();

    final arItem = AppStrings.ofLocaleState(state, 'admin.language_arabic');
    await tester.tap(find.text(arItem));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(state.isArabic, isTrue);
    final arBadge = AppStrings.ofLocaleState(state, 'admin.badge');
    expect(arBadge, isNot(enBadge));
    expect(find.text(arBadge), findsOneWidget);

    final updated = AppStrings.ofLocaleState(state, 'admin.language_updated');
    expect(find.text(updated), findsOneWidget);

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
