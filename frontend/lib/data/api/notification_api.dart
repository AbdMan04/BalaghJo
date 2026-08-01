import 'api_client.dart';
import '../models/notification.dart';

class NotificationApi {
  final ApiClient _api = ApiClient.instance;

  Future<List<AppNotification>> list() async {
    final res = await _api.get('/api/notifications');
    return ((res['notifications'] as List?) ?? const [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _api.patch('/api/notifications/read', {'ids': ids});
  }

  Future<void> registerDeviceToken(String token) =>
      _api.post('/api/auth/device-token', {'token': token});

  Future<void> unregisterDeviceToken(String token) =>
      _api.delete('/api/auth/device-token', body: {'token': token});
}
