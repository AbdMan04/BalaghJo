enum ReportStatus { pending, inProgress, resolved }

extension ReportStatusX on ReportStatus {
  String get apiValue => switch (this) {
        ReportStatus.pending => 'pending',
        ReportStatus.inProgress => 'in_progress',
        ReportStatus.resolved => 'resolved',
      };
  String get label => switch (this) {
        ReportStatus.pending => 'Sent',
        ReportStatus.inProgress => 'Processing',
        ReportStatus.resolved => 'Resolved',
      };
  static ReportStatus fromApi(String? v) => switch (v) {
        'in_progress' => ReportStatus.inProgress,
        'resolved' => ReportStatus.resolved,
        _ => ReportStatus.pending,
      };
}

class Report {
  final String id;
  final String reportId;
  final String category;
  final String title;
  final String description;
  final String photoUrl;
  final String address;
  final double lat;
  final double lng;
  final ReportStatus status;
  final String priority;
  final String assignedTo;
  final DateTime? estimatedFix;
  final DateTime createdAt;

  Report({
    required this.id,
    required this.reportId,
    required this.category,
    required this.title,
    required this.description,
    required this.photoUrl,
    required this.address,
    required this.lat,
    required this.lng,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.createdAt,
    this.estimatedFix,
  });

  factory Report.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map?)?.cast<String, dynamic>();
    final coords = (loc?['coordinates'] as List?)?.cast<num>() ?? const [0, 0];
    return Report(
      id: j['id'] ?? j['_id'] ?? '',
      reportId: j['reportId'] ?? '',
      category: j['category'] ?? 'other',
      title: j['title'] ?? '',
      description: j['description'] ?? '',
      photoUrl: j['photoUrl'] ?? '',
      address: j['address'] ?? '',
      lng: coords.isNotEmpty ? coords[0].toDouble() : 0,
      lat: coords.length > 1 ? coords[1].toDouble() : 0,
      status: ReportStatusX.fromApi(j['status']),
      priority: j['priority'] ?? 'medium',
      assignedTo: j['assignedTo'] ?? '',
      estimatedFix: j['estimatedFix'] != null ? DateTime.tryParse(j['estimatedFix']) : null,
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
