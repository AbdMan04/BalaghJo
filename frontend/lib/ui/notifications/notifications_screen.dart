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
  bool _selecting = false;
  final Set<String> _selected = {};

  @override
  Duration get pollInterval => const Duration(seconds: 5);

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
    if (_selecting) return;
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
      Navigator.of(context)
          .push(instantRoute(ReportDetailScreen(reportId: n.reportId)));
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

  void _startSelecting(String id) {
    setState(() {
      _selecting = true;
      _selected
        ..clear()
        ..add(id);
    });
  }

  void _beginSelecting() {
    setState(() {
      _selecting = true;
      _selected.clear();
    });
  }

  void _exitSelecting() {
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selected.length == _items.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_items.map((n) => n.id));
      }
    });
  }

  Future<void> _confirmDelete() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(ctx.t('notif.delete_confirm_title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          ctx.t('notif.delete_confirm_body').replaceAll('{n}', '${ids.length}'),
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.t('common.cancel'),
                style: const TextStyle(
                    color: AppColors.navy, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.t('common.delete'),
                style: const TextStyle(
                    color: AppColors.amber, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.deleteSelected(ids);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _items = _items.where((n) => !ids.contains(n.id)).toList();
      _selecting = false;
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        content: Text(context.t('notif.deleted_toast'),
            style: const TextStyle(color: Colors.white)),
      ),
    );
  }

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
        leading: _selecting
            ? IconButton(
                tooltip: context.t('common.close'),
                onPressed: _exitSelecting,
                icon: const Icon(Icons.close, color: AppColors.navy),
              )
            : null,
        title: Text(
          _selecting
              ? context
                  .t('notif.selected_count')
                  .replaceAll('{n}', '${_selected.length}')
              : context.t('notif.title'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_selecting) ...[
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(context.t('notif.select_all'),
                  style: const TextStyle(
                      color: AppColors.navy, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: context.t('common.delete'),
              onPressed: _selected.isEmpty ? null : _confirmDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.navy),
            ),
          ] else ...[
            if (_unread > 0)
              IconButton(
                tooltip: context.t('notif.mark_all'),
                onPressed: _markAll,
                icon: const Icon(Icons.done_all, color: AppColors.navy),
              ),
            IconButton(
              tooltip: context.t('notif.delete'),
              onPressed: _items.isEmpty ? null : _beginSelecting,
              icon: const Icon(Icons.delete_outline, color: AppColors.navy),
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child:
              CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue));
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
    final selected = _selected.contains(n.id);
    return PressableScale(
      onTap: _selecting ? () => _toggleSelect(n.id) : () => _open(n),
      onLongPress: _selecting ? null : () => _startSelecting(n.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected
                ? AppColors.amber
                : n.read
                    ? AppColors.border
                    : AppColors.blue.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selecting) ...[
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.amber : Colors.white,
                  border: Border.all(
                    color: selected ? AppColors.amber : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 16, color: AppColors.ink)
                    : null,
              ),
              const SizedBox(width: 12),
            ],
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: (n.read ? AppColors.textMuted : AppColors.navy)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                n.read
                    ? Icons.check_circle_outline
                    : Icons.notifications_active_outlined,
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
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: onRetry, child: Text(context.t('common.retry'))),
            ],
          ],
        ),
      ),
    );
  }
}
