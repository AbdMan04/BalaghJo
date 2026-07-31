enum ReportStatus { pending, inProgress, resolved }

class StatusEvent {
  final ReportStatus status;
  final DateTime changedAt;
  final String changedBy;
  StatusEvent({required this.status, required this.changedAt, this.changedBy = ''});

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        status: ReportStatusX.fromApi(j['status']),
        changedAt: DateTime.tryParse(j['changedAt'] ?? '') ?? DateTime.now(),
        changedBy: j['changedBy'] ?? '',
      );
}

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
  // FR-10: statuses labelled in Arabic and English.
  String get labelAr => switch (this) {
        ReportStatus.pending => 'قيد الانتظار',
        ReportStatus.inProgress => 'قيد المعالجة',
        ReportStatus.resolved => 'تم الحل',
      };
  String get bilingualLabel => '$labelAr · $label';
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
  final DateTime? statusChangedAt;
  final List<StatusEvent> statusHistory;
  final String assignedTo;
  final DateTime? estimatedFix;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String reporterName;
  final String reporterPhone;
  final String reporterEmail;

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
    required this.assignedTo,
    required this.createdAt,
    this.statusChangedAt,
    this.statusHistory = const [],
    this.updatedAt,
    this.estimatedFix,
    this.reporterName = '',
    this.reporterPhone = '',
    this.reporterEmail = '',
  });

  factory Report.fromJson(Map<String, dynamic> j) {
    final loc = (j['location'] as Map?)?.cast<String, dynamic>();
    final coords = (loc?['coordinates'] as List?)?.cast<num>() ?? const [0, 0];
    final reporter = (j['reporter'] as Map?)?.cast<String, dynamic>() ?? const {};
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
      statusChangedAt: j['statusChangedAt'] != null
          ? DateTime.tryParse(j['statusChangedAt'])
          : null,
      statusHistory: ((j['statusHistory'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => StatusEvent.fromJson(e.cast<String, dynamic>()))
          .toList(),
      assignedTo: j['assignedTo'] ?? '',
      estimatedFix: j['estimatedFix'] != null ? DateTime.tryParse(j['estimatedFix']) : null,
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: j['updatedAt'] != null ? DateTime.tryParse(j['updatedAt']) : null,
      reporterName: reporter['fullName'] ?? '',
      reporterPhone: reporter['phone'] ?? '',
      reporterEmail: reporter['email'] ?? '',
    );
  }

  // F4/NFR-6: stable identity key so the 3s poller can cheaply detect
  // whether a report's status (or anything else) changed server-side.
  String get pollKey =>
      '$id|$status|${updatedAt?.millisecondsSinceEpoch ?? createdAt.millisecondsSinceEpoch}';

  static bool sameStatusList(List<Report> a, List<Report> b) {
    if (a.length != b.length) return false;
    final keys = {for (final r in a) r.id: r.pollKey};
    for (final r in b) {
      if (keys[r.id] != r.pollKey) return false;
    }
    return true;
  }
}
