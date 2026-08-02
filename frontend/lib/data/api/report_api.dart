import 'dart:io';
import '../models/report.dart';
import 'api_client.dart';

class ReportSummary {
  final int total, resolved, active;
  final List<Report> recent;
  ReportSummary(
      {required this.total,
      required this.resolved,
      required this.active,
      required this.recent});
}

class ReportApi {
  final ApiClient _api = ApiClient.instance;

  Future<ReportSummary> summary() async {
    final res = await _api.get('/api/reports/summary');
    final s = res['summary'] as Map<String, dynamic>;
    final recent = ((res['recent'] as List?) ?? [])
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
    return ReportSummary(
      total: s['total'] ?? 0,
      resolved: s['resolved'] ?? 0,
      active: s['active'] ?? 0,
      recent: recent,
    );
  }

  Future<List<Report>> list({String? status}) async {
    final res = await _api.get('/api/reports',
        query: status != null ? {'status': status} : null);
    return ((res['reports'] as List?) ?? [])
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Report>> publicList({String? status, String? category}) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status;
    if (category != null) query['category'] = category;
    final res = await _api.get('/api/reports/public',
        query: query.isEmpty ? null : query);
    return ((res['reports'] as List?) ?? [])
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Report> get(String id) async {
    final res = await _api.get('/api/reports/$id');
    return Report.fromJson(res['report']);
  }

  Future<List<Report>> nearby({
    required double lat,
    required double lng,
    String? category,
  }) async {
    final res = await _api.post('/api/reports/nearby', {
      'lat': lat,
      'lng': lng,
      if (category != null) 'category': category,
    });
    return ((res['reports'] as List?) ?? [])
        .map((e) => Report.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> delete(String id) async {
    await _api.delete('/api/reports/$id');
  }

  Future<Report> create({
    required String category,
    required String description,
    String? title,
    String? address,
    double? lat,
    double? lng,
    File? photo,
  }) async {
    final fields = <String, String>{
      'category': category,
      'description': description,
      if (title != null) 'title': title,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat.toString(),
      if (lng != null) 'lng': lng.toString(),
    };
    final res =
        await _api.multipart('/api/reports', fields: fields, file: photo);
    return Report.fromJson(res['report']);
  }
}
