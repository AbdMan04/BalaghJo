class CategoryCount {
  final String category;
  final int count;
  const CategoryCount({required this.category, required this.count});

  factory CategoryCount.fromJson(Map<String, dynamic> j) => CategoryCount(
        category: j['category'] ?? 'other',
        count: (j['count'] ?? 0) as int,
      );
}

class DailyCount {
  final DateTime date;
  final int count;
  const DailyCount({required this.date, required this.count});

  factory DailyCount.fromJson(Map<String, dynamic> j) => DailyCount(
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        count: (j['count'] ?? 0) as int,
      );
}

class AdminStats {
  final int total;
  final int pending;
  final int inProgress;
  final int resolved;
  final int active;
  final int users;
  final List<CategoryCount> categories;
  final List<DailyCount> daily;

  const AdminStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.resolved,
    required this.active,
    required this.users,
    this.categories = const [],
    this.daily = const [],
  });

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        total: (j['total'] ?? 0) as int,
        pending: (j['pending'] ?? 0) as int,
        inProgress: (j['inProgress'] ?? 0) as int,
        resolved: (j['resolved'] ?? 0) as int,
        active: (j['active'] ?? 0) as int,
        users: (j['users'] ?? 0) as int,
        categories: ((j['categories'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => CategoryCount.fromJson(e.cast<String, dynamic>()))
            .toList(),
        daily: ((j['daily'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => DailyCount.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
