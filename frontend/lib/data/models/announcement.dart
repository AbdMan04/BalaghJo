enum AnnouncementAudience {
  all('all'),
  category('category'),
  user('user');

  final String apiValue;
  const AnnouncementAudience(this.apiValue);

  static AnnouncementAudience fromApi(String? v) => switch (v) {
        'category' => AnnouncementAudience.category,
        'user' => AnnouncementAudience.user,
        _ => AnnouncementAudience.all,
      };
}

class AdminAnnouncement {
  final String id;
  final String title;
  final String body;
  final AnnouncementAudience audience;
  final String? audienceCategory;
  final String? audienceUserId;
  final int recipients;
  final int pushed;
  final String sentBy;
  final DateTime createdAt;

  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    this.audienceCategory,
    this.audienceUserId,
    required this.recipients,
    required this.pushed,
    required this.sentBy,
    required this.createdAt,
  });

  factory AdminAnnouncement.fromJson(Map<String, dynamic> j) {
    final aud = (j['audience'] as Map?)?.cast<String, dynamic>() ?? const {};
    return AdminAnnouncement(
      id: j['id'] ?? '',
      title: j['title'] ?? '',
      body: j['body'] ?? '',
      audience: AnnouncementAudience.fromApi(aud['type']),
      audienceCategory: aud['category'] as String?,
      audienceUserId: aud['userId'] as String?,
      recipients: (j['recipients'] ?? 0) as int,
      pushed: (j['pushed'] ?? 0) as int,
      sentBy: j['sentBy'] ?? '',
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
