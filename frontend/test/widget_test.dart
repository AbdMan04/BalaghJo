import 'package:flutter_test/flutter_test.dart';

import 'package:balaghjo/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BalaghjoApp());
    await tester.pump();
  });
}
