// FR-19: clustering activates only when more than 50 pins are in the
// viewport; nearby pins merge into numbered bubbles; the legend lists the
// colour of every category plus the cluster bubble.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:balaghjo/core/locale_state.dart';
import 'package:balaghjo/core/map_config.dart';
import 'package:balaghjo/data/models/report.dart';
import 'package:balaghjo/ui/reports/widgets/report_cluster_layer.dart';

Report _report(int i, double lat, double lng, {String category = 'pothole'}) =>
    Report(
      id: 'r$i',
      reportId: 'RPT-$i',
      category: category,
      title: '',
      description: '',
      photoUrl: '',
      address: '',
      lat: lat,
      lng: lng,
      status: ReportStatus.pending,
      assignedTo: '',
      createdAt: DateTime(2026, 1, 1),
    );

// n reports packed within a few metres of (lat, lng).
List<Report> _packed(int n, double lat, double lng, {int idOffset = 0}) => [
      for (var i = 0; i < n; i++)
        _report(idOffset + i, lat + i * 0.00001, lng + i * 0.00001),
    ];

// 1 degree = 1000 px, so the 72 px cells are 0.072 degrees wide.
math.Point<double> _project(LatLng p) =>
    math.Point(p.longitude * 1000, -p.latitude * 1000);

bool _all(LatLng _) => true;

void main() {
  group('clusterReports', () {
    test('50 visible pins stay individual pins', () {
      final clusters = clusterReports(_packed(50, 32.55, 35.85),
          project: _project, isVisible: _all);
      expect(clusters, hasLength(50));
      expect(clusters.every((c) => c.isSingle), isTrue);
    });

    test('51 visible pins activate clustering', () {
      final clusters = clusterReports(_packed(51, 32.55, 35.85),
          project: _project, isVisible: _all);
      expect(clusters, hasLength(1));
      expect(clusters.single.reports, hasLength(51));
    });

    test('only pins inside the viewport count toward the threshold', () {
      final reports = _packed(80, 32.55, 35.85);
      var seen = 0;
      // Only the first 40 are "visible".
      bool firstForty(LatLng _) => seen++ < 40;
      final clusters =
          clusterReports(reports, project: _project, isVisible: firstForty);
      expect(clusters, hasLength(80));
    });

    test('far-apart groups form separate clusters and lone pins stay pins',
        () {
      final reports = [
        ..._packed(30, 32.55, 35.85),
        ..._packed(30, 32.65, 35.95, idOffset: 100),
        _report(999, 32.45, 35.70),
      ];
      final clusters =
          clusterReports(reports, project: _project, isVisible: _all);
      expect(clusters, hasLength(3));
      final sizes = clusters.map((c) => c.reports.length).toList()..sort();
      expect(sizes, [1, 30, 30]);
    });

    test('a cluster sits at the mean position of its reports', () {
      // 35.80 and 35.81 project to 35800 and 35810 px: the same 72 px cell.
      final reports = [
        for (var i = 0; i < 51; i++) _report(i, 32.55, i.isEven ? 35.80 : 35.81),
      ];
      final c = clusterReports(reports, project: _project, isVisible: _all)
          .single;
      expect(c.center.latitude, closeTo(32.55, 1e-9));
      // 26 at 35.80 and 25 at 35.81.
      expect(c.center.longitude, closeTo(35.80 + 0.01 * 25 / 51, 1e-9));
    });
  });

  group('ReportClusterLayer', () {
    Widget map(List<Report> reports) => MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: FlutterMap(
                options: const MapOptions(
                  initialCenter: MapConfig.irbidCenter,
                  initialZoom: 13,
                ),
                children: [
                  ReportClusterLayer(
                    reports: reports,
                    selectedId: null,
                    onSelect: (_) {},
                  ),
                ],
              ),
            ),
          ),
        );

    testWidgets('renders individual pins at or below the threshold',
        (tester) async {
      await tester.pumpWidget(map(_packed(10, 32.5556, 35.85)));
      await tester.pump();
      expect(find.byType(ReportPin), findsNWidgets(10));
      expect(find.byType(ClusterBubble), findsNothing);
    });

    testWidgets('renders a numbered bubble above the threshold',
        (tester) async {
      await tester.pumpWidget(map(_packed(60, 32.5556, 35.85)));
      await tester.pump();
      expect(find.byType(ClusterBubble), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
      expect(find.byType(ReportPin), findsNothing);
    });
  });

  group('MapLegend', () {
    Widget legend(double width) => ChangeNotifierProvider(
          create: (_) => LocaleState(),
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(size: Size(width, 800)),
                child: const Align(
                    alignment: Alignment.topLeft, child: MapLegend()),
              ),
            ),
          ),
        );

    testWidgets('lists every category colour and the cluster bubble',
        (tester) async {
      await tester.pumpWidget(legend(1024));
      await tester.pump();
      for (final label in ['Pothole', 'Waste', 'Broken Light', 'Other']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('Group of reports (tap to zoom)'), findsOneWidget);
    });

    testWidgets('starts collapsed on phones and expands on tap',
        (tester) async {
      await tester.pumpWidget(legend(390));
      await tester.pump();
      expect(find.text('Pothole'), findsNothing);
      await tester.tap(find.byKey(const Key('map_legend')));
      await tester.pump();
      expect(find.text('Pothole'), findsOneWidget);
    });
  });
}
