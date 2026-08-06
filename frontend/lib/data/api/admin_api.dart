// AdminApi — dashboard (F5) data access for role=admin users.
//
// Talks to the admin-gated report feed (GET /api/admin/reports) and the
// shared status-update endpoint (PATCH /api/reports/:id/status), both of
// which require a Bearer token whose role claim is 'admin'.
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
    final reports = ((res['reports'] as List?) ?? [])
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
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
}