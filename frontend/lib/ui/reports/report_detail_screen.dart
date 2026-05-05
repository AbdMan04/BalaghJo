import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../data/api/report_api.dart';
import '../../data/models/report.dart';
import '../widgets/animations.dart';
import '../widgets/category_icon.dart';
import '../widgets/status_badge.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Future<Report> _future;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _future = ReportApi().get(widget.reportId);
  }

  void _share(Report r) {
    final text = 'Report ${r.reportId}\n'
        '${r.title.isNotEmpty ? r.title : labelForCategory(r.category)}\n'
        'Status: ${r.status.label}\n'
        '${r.address.isNotEmpty ? r.address : ""}\n'
        '${r.description}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('Report details copied to clipboard'),
        ]),
      ),
    );
  }

  void _toggleFollow() {
    setState(() => _following = !_following);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        content: Text(_following
            ? 'Following — you\'ll be notified of updates'
            : 'Stopped following this report'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Detail', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Report>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.blue));
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final r = snap.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeSlideIn(
                  child: Hero(
                    tag: 'report-icon-${r.id}',
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: r.photoUrl.isEmpty
                          ? Center(
                              child: Icon(iconForCategory(r.category),
                                  size: 64, color: AppColors.textMuted.withValues(alpha: 0.6)),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Image.network(
                                '${AppConfig.apiBaseUrl}${r.photoUrl}',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r.title.isNotEmpty ? r.title : labelForCategory(r.category),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                      ),
                      StatusBadge(r.status),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: Text('Report ID: ${r.reportId} · ${r.priority} priority',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
                const SizedBox(height: 10),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: AppColors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(r.address.isNotEmpty ? r.address : 'Location not provided',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FadeSlideIn(delay: const Duration(milliseconds: 260), child: _section('REPORT INFO')),
                FadeSlideIn(delay: const Duration(milliseconds: 300), child: _kv('Category', labelForCategory(r.category))),
                FadeSlideIn(delay: const Duration(milliseconds: 340), child: _kv('Submitted', DateFormat.yMMMd().format(r.createdAt))),
                if (r.assignedTo.isNotEmpty)
                  FadeSlideIn(delay: const Duration(milliseconds: 380), child: _kv('Assigned to', r.assignedTo)),
                if (r.estimatedFix != null)
                  FadeSlideIn(delay: const Duration(milliseconds: 420), child: _kv('Est. Fix', DateFormat.yMMMd().format(r.estimatedFix!))),
                const SizedBox(height: 18),
                FadeSlideIn(delay: const Duration(milliseconds: 460), child: _section('USER DESCRIPTION')),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(r.description, style: const TextStyle(height: 1.5)),
                  ),
                ),
                const SizedBox(height: 24),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 560),
                  child: Row(
                    children: [
                      Expanded(
                        child: PressableScale(
                          onTap: () => _share(r),
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.share_outlined, size: 18, color: AppColors.navy),
                                SizedBox(width: 6),
                                Text('Share', style: TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PressableScale(
                          onTap: _toggleFollow,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            height: 48,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _following ? AppColors.blue : AppColors.blue.withValues(alpha: 0.08),
                              border: Border.all(color: AppColors.blue),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _following ? Icons.notifications_active : Icons.notifications_outlined,
                                  size: 18,
                                  color: _following ? Colors.white : AppColors.blue,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _following ? 'Following' : 'Follow',
                                  style: TextStyle(
                                    color: _following ? Colors.white : AppColors.blue,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.6)),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          ],
        ),
      );
}
