class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String role;
  final String provider;
  final int sentReports;
  final int solvedReports;
  final bool isVerified;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.provider,
    this.phone,
    this.sentReports = 0,
    this.solvedReports = 0,
    this.isVerified = true,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isAdmin => role == 'admin';

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] ?? j['_id'] ?? '',
        firstName: j['firstName'] ?? '',
        lastName: j['lastName'] ?? '',
        phone: j['phone'],
        role: j['role'] ?? 'user',
        provider: j['provider'] ?? 'phone',
        sentReports: (j['sentReports'] ?? 0) as int,
        solvedReports: (j['solvedReports'] ?? 0) as int,
        isVerified: j['isVerified'] ?? true,
        createdAt:
            j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      );
}
