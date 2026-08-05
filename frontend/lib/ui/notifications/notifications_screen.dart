// NotificationsScreen — FR-7 (push notifications). Lists in-app
// notifications (report status updates) with unread indicators, and
// opens the related report when tapped. Refreshes periodically while
// visible so a status change pushed from the backend appears promptly.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/locale_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/notification_api.dart';
import '../../data/models/notification.dart';
import '../reports/report_detail_screen.dart';
import '../widgets/animations.dart';
import '../widgets/route_aware_polling.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with RouteAwarePolling {
  final NotificationApi _api = NotificationApi();
  List<AppNotification> _items = const [];
  bool _loading = true;
  bool _fetching = false;
  bool _error = false;

  @override
  Duration get pollInterval => const Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> poll() => _load();

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final items = await _api.list();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _items.isEmpty;
      });
    } finally {
      _fetching = false;
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      await _api.markRead([n.id]);
      setState(() {
        final index = _items.indexWhere((x) => x.id == n.id);
        if (index >= 0) {
          final updated = List<AppNotification>.from(_items);
          updated[index] = AppNotification(
            id: n.id,
            type: n.type,
            reportId: n.reportId,
            title: n.title,
            body: n.body,
            read: true,
            createdAt: n.createdAt,
          );
          _items = updated;
        }
      });
    }
    if (n.reportId.isNotEmpty && mounted) {
      Navigator.of(context).push(instantRoute(ReportDetailScreen(reportId: n.reportId)));
    }
  }

  Future<void> _markAll() async {
    final unread = _items.where((n) => !n.read).map((n) => n.id).toList();
    if (unread.isEmpty) return;
    await _api.markRead(unread);
    setState(() {
      _items = [
        for (final n in _items)
          AppNotification(
            id: n.id,
            type: n.type,
            reportId: n.reportId,
            title: n.title,
            body: n.body,
            read: true,
            createdAt: n.createdAt,
          ),
      ];
    });
  }

  int get _unread => _items.where((n) => !n.read).length;

  String _timeAgo(BuildContext context, DateTime dt) {
    final locale = context.watch<LocaleState>().isArabic ? 'ar' : 'en';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return context.t('notif.just_now');
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return DateFormat('h:mm a', locale).format(dt);
    return DateFormat('MMM d', locale).format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(context.t('notif.title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (_unread > 0)
            IconButton(
              tooltip: context.t('notif.mark_all'),
              onPressed: _markAll,
              icon: const Icon(Icons.done_all, color: AppColors.navy),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue));
    }
    if (_error) {
      return _CenteredMessage(
        icon: Icons.cloud_off_outlined,
        title: context.t('common.error'),
        onRetry: () {
          setState(() => _loading = true);
          _load();
        },
      );
    }
    if (_items.isEmpty) {
      return _CenteredMessage(
        icon: Icons.notifications_none,
        title: context.t('notif.empty'),
        subtitle: context.t('notif.empty_sub'),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _tile(_items[index]),
      ),
    );
  }

  Widget _tile(AppNotification n) {
    return PressableScale(
      onTap: () => _open(n),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
              color: n.read ? AppColors.border : AppColors.blue.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: (n.read ? AppColors.textMuted : AppColors.navy)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                n.read ? Icons.check_circle_outline : Icons.notifications_active_outlined,
                color: n.read ? AppColors.textMuted : AppColors.navy,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      Text(_timeAgo(context, n.createdAt),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(n.body,
                      style: TextStyle(
                          color: n.read ? AppColors.textMuted : Colors.black87,
                          fontSize: 13)),
                ],
              ),
            ),
            if (!n.read)
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 6),
                child: CircleAvatar(radius: 4, backgroundColor: AppColors.blue),
              ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  const _CenteredMessage({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(context.t('common.retry'))),
            ],
          ],
        ),
      ),
    );
  }
}
