/* 
- ReportDetailScreen — feature F3 (Report List & History, FR-9 detail
  view) plus feature F4 (FR-10 status timeline display and FR-11/NFR-6
  real-time refresh). Every 3s the screen polls the single-report
  endpoint and, when the server-side status/updatedAt changed, swaps in
  the fresh report without an app restart.
- Single-report view shown from the My Reports list or from a recent-
  reports tile on the home screen.
*/
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/geocoding_api.dart';
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
  Report? _last;
  Timer? _pollTimer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<Report> _load() async {
    final r = await ReportApi().get(widget.reportId);
    _last = r;
    return r;
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final fresh = await ReportApi().get(widget.reportId);
      if (!mounted) return;
      final changed = _last == null || _last!.pollKey != fresh.pollKey;
      _last = fresh;
      if (changed) {
        setState(() => _future = Future.value(fresh));
      }
    } catch (_) {
      // Keep showing the last good report on transient network errors.
    } finally {
      _polling = false;
    }
  }

  String _shareText(Report r) => 'Report ${r.reportId}\n'
      '${r.title.isNotEmpty ? r.title : labelForCategory(r.category, context)}\n'
      'Status: ${r.status.label}\n'
      '${r.address.isNotEmpty ? r.address : ""}\n'
      '${r.description}';

  Future<void> _share(Report r) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareSheet(report: r, text: _shareText(r)),
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
        title: Text(context.t('detail.title'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<Report>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
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
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorForCategory(r.category).withValues(alpha: 0.18),
                                    colorForCategory(r.category).withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              child: Center(
                                child: Icon(iconForCategory(r.category),
                                    size: 72, color: colorForCategory(r.category)),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Image.network(
                                AppConfig.imageUrl(r.photoUrl),
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
                        child: Text(r.title.isNotEmpty ? r.title : labelForCategory(r.category, context),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                      ),
                      StatusBadge(r.status),
                    ],
                  ),
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
                        Expanded(child: _LocationText(report: r)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 230),
                  child: _StatusTimeline(
                    status: r.status,
                    statusHistory: r.statusHistory,
                    submittedAt: r.createdAt,
                    estimatedFix: r.estimatedFix,
                  ),
                ),
                const SizedBox(height: 22),
                FadeSlideIn(delay: const Duration(milliseconds: 260), child: _section(context.t('detail.report_info'))),
                FadeSlideIn(delay: const Duration(milliseconds: 300), child: _kv(context.t('detail.category'), context.t('cat.${r.category}'))),
                FadeSlideIn(delay: const Duration(milliseconds: 340), child: _kv(context.t('detail.submitted_on'), DateFormat.yMMMd().format(r.createdAt))),
                if (r.statusChangedAt != null)
                  FadeSlideIn(delay: const Duration(milliseconds: 360), child: _kv(context.t('detail.last_updated'), DateFormat.yMMMd().add_Hm().format(r.statusChangedAt!))),
                if (r.assignedTo.isNotEmpty)
                  FadeSlideIn(delay: const Duration(milliseconds: 380), child: _kv(context.t('detail.assigned_to'), r.assignedTo)),
                if (r.estimatedFix != null)
                  FadeSlideIn(delay: const Duration(milliseconds: 420), child: _kv(context.t('detail.est_fix'), DateFormat.yMMMd().format(r.estimatedFix!))),
                const SizedBox(height: 18),
                if (r.reporterPhone.isNotEmpty || r.reporterName.isNotEmpty) ...[
                  FadeSlideIn(delay: const Duration(milliseconds: 440), child: _section(context.t('detail.reporter_contact'))),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 470),
                    child: _ReporterCard(report: r),
                  ),
                  const SizedBox(height: 18),
                ],
                FadeSlideIn(delay: const Duration(milliseconds: 460), child: _section(context.t('detail.user_description'))),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.share_outlined, size: 18, color: AppColors.navy),
                                const SizedBox(width: 6),
                                Text(context.t('common.share'), style: const TextStyle(fontWeight: FontWeight.w700)),
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
                                  _following ? context.t('detail.following') : context.t('detail.follow'),
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

class _ReporterCard extends StatelessWidget {
  final Report report;
  const _ReporterCard({required this.report});

  Future<void> _call(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: report.reporterPhone);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open dialer')),
      );
    }
  }

  Future<void> _copyPhone(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: report.reporterPhone));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        content: const Text('Phone number copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = report.reporterPhone.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.person, color: AppColors.blue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.reporterName.isNotEmpty ? report.reporterName : 'Reporter',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasPhone) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(report.reporterPhone,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                PressableScale(
                  onTap: () => _copyPhone(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.copy, size: 16, color: AppColors.navy),
                  ),
                ),
                const SizedBox(width: 8),
                PressableScale(
                  onTap: () => _call(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.success, Color(0xFF16A34A)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.phone, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Call',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            const Text(
              'No phone number on file for this reporter.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationText extends StatefulWidget {
  final Report report;
  const _LocationText({required this.report});

  @override
  State<_LocationText> createState() => _LocationTextState();
}

class _LocationTextState extends State<_LocationText> {
  String? _resolved;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.report;
    final hasCoords = r.lat != 0 || r.lng != 0;
    if (r.address.isEmpty && hasCoords) {
      _loading = true;
      GeocodingApi().reverseLookup(r.lat, r.lng).then((name) {
        if (!mounted) return;
        setState(() {
          _resolved = name;
          _loading = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final hasAddress = r.address.isNotEmpty;
    final hasCoords = r.lat != 0 || r.lng != 0;

    if (!hasAddress && !hasCoords) {
      return const Text('Location not provided',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600));
    }

    final primary = hasAddress
        ? r.address
        : (_loading
            ? 'Looking up address…'
            : (_resolved != null && _resolved!.isNotEmpty
                ? _resolved!
                : 'Unnamed location near GPS ${r.lat.toStringAsFixed(4)}, ${r.lng.toStringAsFixed(4)}'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(primary,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
            if (_loading)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.blue),
              ),
          ],
        ),
      ],
    );
  }
}

class _ShareSheet extends StatelessWidget {
  final Report report;
  final String text;
  const _ShareSheet({required this.report, required this.text});

  Future<void> _toWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  Future<void> _moreApps(BuildContext context) async {
    await SharePlus.instance.share(
      ShareParams(text: text, title: report.reportId, subject: report.reportId),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Share Report',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 4),
            Text(report.reportId, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: () => _toWhatsApp(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.chat, color: Colors.white, size: 22),
                          SizedBox(height: 6),
                          Text('WhatsApp',
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PressableScale(
                    onTap: () => _moreApps(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.ios_share, color: AppColors.blue, size: 22),
                          SizedBox(height: 6),
                          Text('More apps',
                              style: TextStyle(
                                  color: AppColors.blue, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PressableScale(
              onTap: () => _copy(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Text('Copy to clipboard',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final ReportStatus status;
  final List<StatusEvent> statusHistory;
  final DateTime submittedAt;
  final DateTime? estimatedFix;
  const _StatusTimeline({
    required this.status,
    required this.statusHistory,
    required this.submittedAt,
    this.estimatedFix,
  });

  int get _activeIndex => switch (status) {
        ReportStatus.pending => 0,
        ReportStatus.inProgress => 1,
        ReportStatus.resolved => 2,
      };

  // Latest recorded time a given status was reached (from the server's
  // append-only statusHistory), so the timeline shows real timestamps.
  DateTime? _reachedAt(ReportStatus s) {
    for (final e in statusHistory.reversed) {
      if (e.status == s) return e.changedAt;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final processingAt = _reachedAt(ReportStatus.inProgress);
    final resolvedAt = _reachedAt(ReportStatus.resolved);
    final steps = [
      (
        label: context.t('detail.status_submitted'),
        icon: Icons.send_rounded,
        sub: DateFormat.MMMd().format(submittedAt),
      ),
      (
        label: context.t('detail.status_processing'),
        icon: Icons.sync_rounded,
        sub: processingAt != null
            ? DateFormat.MMMd().add_Hm().format(processingAt)
            : (estimatedFix != null
                ? '${context.t('detail.eta_prefix')}${DateFormat.MMMd().format(estimatedFix!)}'
                : context.t('detail.in_review')),
      ),
      (
        label: context.t('detail.status_resolved'),
        icon: Icons.check_circle_rounded,
        sub: resolvedAt != null
            ? DateFormat.MMMd().add_Hm().format(resolvedAt)
            : (status == ReportStatus.resolved ? context.t('detail.done') : context.t('detail.pending')),
      ),
    ];
    final active = _activeIndex;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final beforeIndex = i ~/ 2;
            final reached = active > beforeIndex;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  height: 2,
                  color: reached ? AppColors.success : AppColors.border,
                ),
              ),
            );
          }
          final idx = i ~/ 2;
          final step = steps[idx];
          final isActive = idx == active;
          final isDone = idx < active;
          final tint = isDone
              ? AppColors.success
              : isActive
                  ? AppColors.blue
                  : AppColors.textMuted.withValues(alpha: 0.6);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                width: isActive ? 38 : 32,
                height: isActive ? 38 : 32,
                decoration: BoxDecoration(
                  color: isDone || isActive ? tint : Colors.white,
                  border: Border.all(color: tint, width: isActive ? 2 : 1.5),
                  shape: BoxShape.circle,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: tint.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : step.icon,
                  color: isDone || isActive ? Colors.white : tint,
                  size: isActive ? 20 : 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isActive || isDone ? AppColors.navy : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                step.sub,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
