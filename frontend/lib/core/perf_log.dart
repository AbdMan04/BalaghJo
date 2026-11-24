// PerfLog — the app's performance / timing log for the NFR measurements.
//
// Each event is one line: `[perf] <UTC ISO timestamp> <event> key=value ...`.
// It goes to the device log (adb logcat / `flutter logs`) on Android and to
// the browser console on the web dashboard, so trial runs can be collected
// and matched against the server's timestamped lines:
//   status_seen     NFR-6 / FR-11  app noticed a status change (pair with the
//                                  server's "[status-update]" line)
//   push_received   NFR-7 / NFR-9  push arrived on the device (pair with the
//                                  PushLog document for the same report)
//   map_render      NFR-10         map + pins on screen after opening
//   dashboard_load  NFR-8          first page of the admin feed rendered
// latencyMs values compare the device clock with the server clock, so keep
// the test device on automatic (network) time.
import 'package:flutter/foundation.dart';

abstract final class PerfLog {
  static void event(String name, [Map<String, Object?> fields = const {}]) {
    final ts = DateTime.now().toUtc().toIso8601String();
    final extra = fields.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    debugPrint('[perf] $ts $name${extra.isEmpty ? '' : ' $extra'}');
  }

  /// Milliseconds from a server timestamp to now, or null when unknown.
  static int? msSince(DateTime? serverTime) => serverTime == null
      ? null
      : DateTime.now().toUtc().difference(serverTime.toUtc()).inMilliseconds;
}
