// FirebaseService — FCM push notifications (FR-7).
//
// Initializes Firebase and keeps the backend's device-token list in sync
// so the API can push report-status updates (Phase 5). Everything is
// guarded: on web (admin dashboard), on platforms without a
// google-services.json, or when the API has push disabled, these calls
// are safe no-ops.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../data/api/notification_api.dart';

class FirebaseService {
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.getToken();
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
