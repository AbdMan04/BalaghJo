class AppNotification {
  final String id;
  final String type;
  final String reportId;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.reportId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] ?? '',
        type: json['type'] ?? 'report_status',
        reportId: json['reportId'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        read: json['read'] ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}
