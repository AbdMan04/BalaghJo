// App-wide RouteObserver. Pollable screens subscribe via RouteAwarePolling
// so their periodic timers pause when they are no longer the visible route.
import 'package:flutter/material.dart';

final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
