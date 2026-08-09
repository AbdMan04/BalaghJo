// End-to-end smoke test: boots the real app and verifies a fresh,
// unauthenticated user lands on the onboarding screen after the splash.
//
// Run on a device/emulator:
//   flutter test integration_test/app_test.dart -d <device>
// or via flutter drive:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:balaghjo/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fresh user boots into onboarding', (tester) async {
    await tester.pumpWidget(const BalaghjoApp());

    // The splash screen runs an infinite spinner while it restores the
    // session (AuthState.bootstrap + a ~1.4s hold), so pump real time
    // instead of pumpAndSettle — which would hang on the spinner.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();

    // No stored session in a clean install: onboarding is the landing page.
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Your Voice Builds the City'), findsOneWidget);
  });
}
