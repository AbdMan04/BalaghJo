// AdminApi — dashboard (F5) data access for role=admin users.
//
// Talks to the admin-gated report feed (GET /api/admin/reports), the
// shared status-update endpoint (PATCH /api/reports/:id/status), the
// dashboard-wide stats (GET /api/admin/stats), user management
// (GET /api/admin/users + role changes) and broadcasts
// (GET/POST /api/admin/announcements). Every call requires a Bearer
// token whose role claim is 'admin'.
import '../models/admin_stats.dart';
import '../models/admin_user.dart';
import '../models/announcement.dart';
import '../models/report.dart';
import 'api_client.dart';

class AdminReportPage {
  final List<Report> reports;
  final String? nextCursor;
  const AdminReportPage({required this.reports, this.nextCursor});
}

class AdminApi {
  final ApiClient _api = ApiClient.instance;

  Future<AdminReportPage> listReports({
    String? status,
    String? category,
    String? query,
    String? before,
    int limit = 50,
  }) async {
    final q = <String, String>{
      'limit': limit.toString(),
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (query != null && query.isNotEmpty) 'q': query,
      if (before != null) 'before': before,
    };
    final res = await _api.get('/api/admin/reports', query: q);
    final reports = ApiClient.parseList(res, 'reports', Report.fromJson);
    return AdminReportPage(
      reports: reports,
      nextCursor: res['nextCursor'] as String?,
    );
  }

  // PATCH /api/reports/:id/status — enforced transitions (Pending ->
  // In Progress -> Resolved); throws ApiException on an illegal move.
  Future<Report> updateStatus(String id, String status) async {
    final res = await _api.patch('/api/reports/$id/status', {'status': status});
    return Report.fromJson(res['report']);
  }

  Future<AdminStats> stats() async {
    final res = await _api.get('/api/admin/stats');
    return AdminStats.fromJson(res['stats'] as Map<String, dynamic>);
  }

  Future<List<AdminUser>> listUsers({String? query}) async {
    final q = <String, String>{};
    if (query != null && query.isNotEmpty) q['q'] = query;
    final res = await _api.get('/api/admin/users', query: q);
    return ApiClient.parseList(res, 'users', AdminUser.fromJson);
  }

  Future<void> setRole(String id, String role) async {
    await _api.patch('/api/admin/users/$id/role', {'role': role});
  }

  Future<List<AdminAnnouncement>> listAnnouncements() async {
    final res = await _api.get('/api/admin/announcements');
    return ApiClient.parseList(res, 'announcements', AdminAnnouncement.fromJson);
  }

  Future<AdminAnnouncement> sendAnnouncement({
    required String title,
    required String body,
    required String audienceType,
    String? category,
    String? userId,
    String? phone,
  }) async {
    final res = await _api.post('/api/admin/announcements', {
      'title': title,
      'body': body,
      'audience': {
        'type': audienceType,
        if (category != null) 'category': category,
        if (userId != null) 'userId': userId,
        if (phone != null) 'phone': phone,
      },
    });
    return AdminAnnouncement.fromJson(res['announcement']);
  }

  Future<List<AdminAnnouncement>> deleteAnnouncement(String id) async {
    final res = await _api.delete('/api/admin/announcements/$id');
    return ApiClient.parseList(res, 'announcements', AdminAnnouncement.fromJson);
  }

  Future<List<AdminAnnouncement>> deleteAllAnnouncements() async {
    final res = await _api.delete('/api/admin/announcements');
    return ApiClient.parseList(res, 'announcements', AdminAnnouncement.fromJson);
  }
}
