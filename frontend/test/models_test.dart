// Model round-trip tests: Report, ReportStatus/ReportCategory enums and
// AppNotification. Guards the single-source-of-truth refactor where screens
// stopped carrying their own status/category literal lists.
import 'package:flutter_test/flutter_test.dart';

import 'package:balaghjo/data/models/notification.dart';
import 'package:balaghjo/data/models/report.dart';
import 'package:balaghjo/ui/widgets/category_icon.dart';

void main() {
  group('ReportStatus', () {
    test('fromApi round-trips every known value', () {
      expect(ReportStatus.fromApi('pending'), ReportStatus.pending);
      expect(ReportStatus.fromApi('in_progress'), ReportStatus.inProgress);
      expect(ReportStatus.fromApi('resolved'), ReportStatus.resolved);
    });

    test('fromApi falls back to pending for unknown values', () {
      expect(ReportStatus.fromApi('deleted'), ReportStatus.pending);
      expect(ReportStatus.fromApi(null), ReportStatus.pending);
    });

    test('apiValue/labels match the backend vocabulary', () {
      expect(ReportStatus.pending.apiValue, 'pending');
      expect(ReportStatus.inProgress.apiValue, 'in_progress');
      expect(ReportStatus.resolved.apiValue, 'resolved');
      expect(ReportStatus.pending.label, 'Sent');
      expect(ReportStatus.inProgress.label, 'Processing');
      expect(ReportStatus.resolved.label, 'Resolved');
    });
  });

  group('ReportCategory', () {
    test('fromApi round-trips every category', () {
      for (final c in ReportCategory.values) {
        expect(ReportCategory.fromApi(c.apiValue), c);
      }
      expect(ReportCategory.fromApi('unknown'), ReportCategory.other);
    });
  });

  group('Report.fromJson', () {
    final now = DateTime.utc(2026, 8, 7, 10, 30);
    final json = <String, dynamic>{
      'id': 'r1',
      'reportId': 'BAL-000123',
      'category': 'pothole',
      'title': 'Broken road',
      'description': 'A deep pothole',
      'photoUrl': '/uploads/x.jpg',
      'address': 'Al-Yarmouk',
      'location': {'coordinates': [31.5, 35.2]},
      'status': 'in_progress',
      'assignedTo': 'Amman Works',
      'statusChangedAt': now.toIso8601String(),
      'statusHistory': [
        {'status': 'pending', 'changedAt': now.subtract(const Duration(days: 1)).toIso8601String(), 'changedBy': 'system'},
      ],
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
      'reporter': {'fullName': 'Ali', 'phone': '0791234567'},
    };

    test('parses every field', () {
      final r = Report.fromJson(json);
      expect(r.id, 'r1');
      expect(r.reportId, 'BAL-000123');
      expect(r.category, 'pothole');
      expect(r.title, 'Broken road');
      expect(r.description, 'A deep pothole');
      expect(r.photoUrl, '/uploads/x.jpg');
      expect(r.address, 'Al-Yarmouk');
      expect(r.lat, 35.2);
      expect(r.lng, 31.5);
      expect(r.status, ReportStatus.inProgress);
      expect(r.assignedTo, 'Amman Works');
      expect(r.statusChangedAt, now);
      expect(r.statusHistory, hasLength(1));
      expect(r.statusHistory.first.status, ReportStatus.pending);
      expect(r.statusHistory.first.changedBy, 'system');
      expect(r.createdAt, now);
      expect(r.updatedAt, now);
      expect(r.reporterName, 'Ali');
      expect(r.reporterPhone, '0791234567');
    });

    test('falls back gracefully on missing/empty fields', () {
      final r = Report.fromJson(const {});
      expect(r.id, '');
      expect(r.reportId, '');
      expect(r.category, 'other');
      expect(r.lat, 0);
      expect(r.lng, 0);
      expect(r.status, ReportStatus.pending);
      expect(r.statusHistory, isEmpty);
      expect(r.reporterName, '');
      expect(r.reporterPhone, '');
    });

    test('pollKey changes when status or update time changes', () {
      final a = Report.fromJson(json);
      final b = Report.fromJson({...json, 'status': 'resolved'});
      final c = Report.fromJson(json);
      expect(a.pollKey, isNot(b.pollKey));
      expect(a.pollKey, c.pollKey);
    });
  });

  group('AppNotification.fromJson', () {
    test('parses a full notification', () {
      final n = AppNotification.fromJson({
        'id': 'n1',
        'type': 'status_change',
        'reportId': 'r1',
        'title': 'Update',
        'body': 'Your report is resolved',
        'read': true,
        'createdAt': '2026-08-07T10:30:00.000Z',
      });
      expect(n.id, 'n1');
      expect(n.type, 'status_change');
      expect(n.reportId, 'r1');
      expect(n.title, 'Update');
      expect(n.body, 'Your report is resolved');
      expect(n.read, isTrue);
      expect(n.createdAt.isUtc, isTrue);
    });

    test('applies defaults on missing fields', () {
      final n = AppNotification.fromJson(const {});
      expect(n.type, 'report_status');
      expect(n.read, isFalse);
      expect(n.title, '');
      expect(n.body, '');
    });
  });
}
