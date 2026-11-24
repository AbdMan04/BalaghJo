// ReportEvents — app-wide signals that connect push notifications to the
// screens that display reports.
//
//  - [changed] ticks when a report-status push arrives while the app is open.
//    Pollable screens (RouteAwarePolling) refresh immediately on a tick, so a
//    status change shows up as soon as the push lands instead of waiting for
//    the next poll (FR-11 / NFR-6). Polling stays as the fallback.
//  - [openRequested] carries a report id (Mongo id or RPT-xxxx ticket) when
//    the user taps a notification (FR-12). The citizen shell consumes it and
//    opens that report's detail screen.
import 'package:flutter/foundation.dart';

abstract final class ReportEvents {
  static final ValueNotifier<int> changed = ValueNotifier<int>(0);
  static final ValueNotifier<String?> openRequested =
      ValueNotifier<String?>(null);

  static void notifyChanged() => changed.value++;

  static void requestOpen(String? reportId) {
    final id = reportId?.trim() ?? '';
    if (id.isEmpty) return;
    // Reset first so tapping the same notification twice still fires.
    openRequested.value = null;
    openRequested.value = id;
  }
}
