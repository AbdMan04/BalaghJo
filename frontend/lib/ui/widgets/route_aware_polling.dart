// RouteAwarePolling — shared polling lifecycle for screens that refresh a
// period endpoint while visible. The timer runs only while the screen is the
// current route (via appRouteObserver) AND the app is resumed (lifecycle
// observer); it restarts with an immediate refresh the moment the screen
// becomes visible again. Combined with the backend TTL cache, this keeps the
// server cost of foreground polling near-zero instead of 3s-per-screen.
//
// Screens that mix this in must implement `poll()`. Each screen keeps its
// own initial load in initState; the mixin only manages the repeating timer.
//
// FR-11 / NFR-6 (status visible within 5s): a status push arriving while the
// app is open (ReportEvents.changed) triggers an immediate poll on the
// visible screen, so updates normally land as soon as the push does; the 3s
// timer is the fallback when push is unavailable (3s + network stays under
// the 5s budget, where 5s + network did not).
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/report_events.dart';
import '../../core/route_observer.dart';

mixin RouteAwarePolling<T extends StatefulWidget> on State<T>
    implements RouteAware {
  Timer? _pollTimer;
  bool _polling = false;
  bool _screenActive = false;
  bool _subscribed = false;
  final _LifecycleForwarder _lifecycle = _LifecycleForwarder();

  // Status-bearing screens need the 3s default to meet the 5s budget; screens
  // without status data (admin feed, notifications) override it upward.
  Duration get pollInterval => const Duration(seconds: 3);

  Future<void> poll();

  @override
  void initState() {
    super.initState();
    _lifecycle.host = this;
    WidgetsBinding.instance.addObserver(_lifecycle);
    ReportEvents.changed.addListener(_onReportChanged);
    // Newly mounted screens run their own initial load, so just arm the
    // timer instead of issuing a redundant fetch here.
    _screenActive = true;
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll());
  }

  void _onReportChanged() {
    if (_screenActive && mounted) _poll();
  }

  // ModalRoute.of resolves through an inherited widget, which is illegal
  // before initState completes, so the route subscription is deferred until
  // the first dependency pass. Guarded so it subscribes exactly once.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subscribed) return;
    _subscribed = true;
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    ReportEvents.changed.removeListener(_onReportChanged);
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(_lifecycle);
    super.dispose();
  }

  @override
  void didPush() => _setScreenActive(true);

  @override
  void didPushNext() => _setScreenActive(false);

  @override
  void didPopNext() => _setScreenActive(true);

  @override
  void didPop() => _setScreenActive(false);

  void _setScreenActive(bool active) {
    if (_screenActive == active) return;
    _screenActive = active;
    if (active) {
      _pollTimer ??= Timer.periodic(pollInterval, (_) => _poll());
      poll();
    } else {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      await poll();
    } finally {
      _polling = false;
    }
  }
}

// Bridges app-lifecycle changes to the host mixin without forcing every
// pollable screen to implement the full WidgetsBindingObserver interface.
class _LifecycleForwarder with WidgetsBindingObserver {
  RouteAwarePolling? host;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    host?._setScreenActive(state == AppLifecycleState.resumed);
  }
}
