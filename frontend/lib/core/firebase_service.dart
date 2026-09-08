// FirebaseService — FCM push notifications (FR-7).
//
// Initializes Firebase, keeps the backend's device-token list in sync so
// the API can push report-status updates, announcements, and new-report
// alerts (Phase 5), and renders notifications:
//   - mobile background/terminated: the top-level background handler shows
//     the system notification via flutter_local_notifications,
//   - mobile foreground: onMessage shows a local notification (FCM only
//     shows the tray notification automatically when the app is not in the
//     foreground),
//   - web (admin dashboard): background/closed-tab pushes are displayed by
//     web/firebase-messaging-sw.js (the browser's own service worker), so
//     nothing runs here while the page is open; getToken() still registers
//     a web token with the backend so the API can push to the browser.
// Everything is guarded: on platforms without a google-services.json or
// when the API has push disabled, these calls are safe no-ops.
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/api/notification_api.dart';
import '../firebase_options.dart';

const _channelId = 'balaghjo';
const _channelName = 'BalaghJo';

// Web-push VAPID key (Firebase Console -> Project settings -> Cloud
// Messaging -> Web Push certificates). It is a public key — safe to commit
// here; the private key stays in the Firebase Console. Override at build
// time with `--dart-define=FCM_VAPID_KEY=<key>` if the project changes.
const _vapidKeyOverride = String.fromEnvironment('FCM_VAPID_KEY');
const _vapidKey = _vapidKeyOverride == ''
    ? 'BLsEoWh7aarVUQeJoaaDxh4TmlupNs_-aSsLelbBb8CqmSxId1bKahNamRZ96o1q3vMHia1YfJqzuLzjHZ-lZjQ'
    : _vapidKeyOverride;

final _localNotifications = FlutterLocalNotificationsPlugin();

// Runs in a separate isolate when the app is backgrounded or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    await _showLocalNotification(message);
  } catch (_) {}
}

Future<void> _initLocalNotifications() async {
  // Transparent brand pin (drawable/ic_notification.xml) instead of the
  // full-color launcher icon, so the status bar shows a clean silhouette.
  const android = AndroidInitializationSettings('ic_notification');
  await _localNotifications
      .initialize(const InitializationSettings(android: android));
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Report status updates and announcements',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      // Road-sign safety yellow — tints the pin instead of the default white.
      color: Color(0xFFFFC72B),
    ),
  );
  await _localNotifications.show(
    DateTime.now().millisecondsSinceEpoch,
    notification.title,
    notification.body,
    details,
    payload: message.data['reportId'] ?? '',
  );
}

class FirebaseService {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    if (kIsWeb) {
      // Web path: initialize the web project so getToken() can issue a
      // browser push token. No local-notifications/background handler —
      // the service worker at /firebase-messaging-sw.js owns those. The
      // browser's permission prompt is deferred to registerToken(), which
      // runs after login, not here at startup.
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        _ready = true;
      } catch (_) {
        // Firebase not configured for this project; push is a no-op.
      }
      return;
    }
    try {
      await Firebase.initializeApp();
      await _initLocalNotifications();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.getToken();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseMessaging.onMessage.listen(_showLocalNotification);
      messaging.onTokenRefresh.listen((token) {
        // Best-effort: only succeeds when an authenticated session exists.
        NotificationApi().registerDeviceToken(token).catchError((_) {});
      });
      _ready = true;
    } catch (_) {
      // Firebase not configured (missing google-services.json); push is a no-op.
    }
  }

  static Future<void> registerToken() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _vapidKey : null,
      );
      if (token != null) await NotificationApi().registerDeviceToken(token);
    } catch (_) {}
  }

  static Future<void> unregisterToken() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? _vapidKey : null,
      );
      if (token != null) await NotificationApi().unregisterDeviceToken(token);
    } catch (_) {}
  }
}
