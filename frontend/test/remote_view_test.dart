// RemoteView widget tests: loading, data, empty, error+retry and the
// GlobalKey<RemoteViewState<T>>.reload() escape hatch that screens rely on
// after filters/pagination changes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:balaghjo/core/locale_state.dart';
import 'package:balaghjo/ui/widgets/remote_view.dart';

void main() {
  Widget host(Widget child) => ChangeNotifierProvider<LocaleState>(
        create: (_) => LocaleState(),
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('shows a spinner while loading', (tester) async {
    final completer = Completer<String>();
    await tester.pumpWidget(host(RemoteView<String>(
      load: () => completer.future,
      builder: (_, data) => Text('data:$data'),
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete('ok');
    await tester.pump();
    expect(find.text('data:ok'), findsOneWidget);
  });

  testWidgets('renders data through the builder', (tester) async {
    await tester.pumpWidget(host(RemoteView<List<int>>(
      load: () async => [1, 2, 3],
      isEmpty: (l) => l.isEmpty,
      builder: (_, data) => Text('count:${data.length}'),
    )));
    await tester.pump();
    expect(find.text('count:3'), findsOneWidget);
  });

  testWidgets('shows the empty state', (tester) async {
    await tester.pumpWidget(host(RemoteView<List<int>>(
      load: () async => [],
      isEmpty: (l) => l.isEmpty,
      emptyMessage: 'Nothing yet',
      builder: (_, data) => Text('count:${data.length}'),
    )));
    await tester.pump();
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('shows the error with a working retry button', (tester) async {
    var calls = 0;
    await tester.pumpWidget(host(RemoteView<String>(
      load: () async {
        calls++;
        if (calls == 1) throw Exception('network down');
        return 'recovered';
      },
      builder: (_, data) => Text('data:$data'),
    )));
    await tester.pump();
    expect(find.textContaining('network down'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(find.text('data:recovered'), findsOneWidget);
  });

  testWidgets('reload() via GlobalKey refetches', (tester) async {
    final key = GlobalKey<RemoteViewState<String>>();
    var calls = 0;
    await tester.pumpWidget(host(RemoteView<String>(
      key: key,
      load: () async => 'call${++calls}',
      builder: (_, data) => Text('data:$data'),
    )));
    await tester.pump();
    expect(find.text('data:call1'), findsOneWidget);

    key.currentState!.reload();
    await tester.pump();
    await tester.pump();
    expect(find.text('data:call2'), findsOneWidget);
  });

  testWidgets('onData fires for each freshly loaded value', (tester) async {
    final seen = <String>[];
    await tester.pumpWidget(host(RemoteView<String>(
      load: () async => 'v1',
      onData: seen.add,
      builder: (_, data) => Text(data),
    )));
    await tester.pump();
    expect(seen, ['v1']);
  });
}
