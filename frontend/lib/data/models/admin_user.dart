class AdminUser {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String role;
  final int sentReports;
  final int solvedReports;
  final bool isVerified;
  final DateTime? createdAt;

  const AdminUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.role,
    required this.sentReports,
    required this.solvedReports,
    required this.isVerified,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isAdmin => role == 'admin';

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] ?? '',
        firstName: j['firstName'] ?? '',
        lastName: j['lastName'] ?? '',
        phone: j['phone'] ?? '',
        role: j['role'] ?? 'user',
        sentReports: (j['sentReports'] ?? 0) as int,
        solvedReports: (j['solvedReports'] ?? 0) as int,
        isVerified: j['isVerified'] ?? true,
        createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt']) : null,
      );
}
