import 'api_client.dart';
import '../models/notification.dart';

class NotificationApi {
  final ApiClient _api = ApiClient.instance;

  Future<List<AppNotification>> list() async {
    final res = await _api.get('/api/notifications');
    return ApiClient.parseList(res, 'notifications', AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final res = await _api.get('/api/notifications/unread-count');
    return (res['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _api.patch('/api/notifications/read', {'ids': ids});
  }

  Future<void> deleteSelected(List<String> ids) async {
    if (ids.isEmpty) return;
    await _api.delete('/api/notifications', body: {'ids': ids});
  }

  Future<void> deleteAll() async {
    await _api.delete('/api/notifications');
  }

  Future<void> registerDeviceToken(String token) =>
      _api.post('/api/auth/device-token', {'token': token});

  Future<void> unregisterDeviceToken(String token) =>
      _api.delete('/api/auth/device-token', body: {'token': token});
}
