// FirebaseService — FCM push notifications (FR-7).
//
// Initializes Firebase, keeps the backend's device-token list in sync so
// the API can push report-status updates and announcements (Phase 5), and
// renders notifications on the device itself:
//   - background/terminated: the top-level background handler shows the
//     system notification via flutter_local_notifications,
//   - foreground: onMessage shows a local notification (FCM only shows the
//     tray notification automatically when the app is not in the
//     foreground), and
//   - a refreshed FCM token is re-registered with the backend.
// Everything is guarded: on web (admin dashboard), on platforms without a
// google-services.json, or when the API has push disabled, these calls are
// safe no-ops.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../data/api/notification_api.dart';

const _channelId = 'balaghjo';
const _channelName = 'BalaghJo';

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
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotifications.initialize(const InitializationSettings(android: android));
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
    if (_ready || kIsWeb) return;
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
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await NotificationApi().registerDeviceToken(token);
    } catch (_) {}
  }

  static Future<void> unregisterToken() async {
    if (!_ready) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await NotificationApi().unregisterDeviceToken(token);
    } catch (_) {}
  }
}
