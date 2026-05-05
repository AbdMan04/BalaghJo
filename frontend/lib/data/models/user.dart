class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phone;
  final String role;
  final int sentReports;
  final int solvedReports;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.phone,
    this.sentReports = 0,
    this.solvedReports = 0,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] ?? j['_id'] ?? '',
        firstName: j['firstName'] ?? '',
        lastName: j['lastName'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'],
        role: j['role'] ?? 'citizen',
        sentReports: (j['sentReports'] ?? 0) as int,
        solvedReports: (j['solvedReports'] ?? 0) as int,
      );
}
