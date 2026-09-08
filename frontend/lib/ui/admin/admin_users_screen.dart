// AdminUsersScreen — user directory for the dashboard. Searchable list of
// accounts with a promote/demote admin toggle. Self and last-admin changes
// are rejected by the backend (and the self toggle is disabled here too).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/debounced_search.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/api/admin_api.dart';
import '../../data/models/admin_user.dart';
import '../../state/auth_state.dart';
import '../widgets/remote_view.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = AdminApi();
  final _search = DebouncedSearch();
  final _listKey = GlobalKey<RemoteViewState<List<AdminUser>>>();
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _search.onQuery = () => _listKey.currentState?.reload();
    _search.attach();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggleRole(AdminUser user, bool makeAdmin) async {
    final myId = context.read<AuthState>().user?.id;
    if (user.id == myId) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('admin.role_confirm_title')),
        content: Text(
          makeAdmin
              ? context
                  .t('admin.role_confirm_admin')
                  .replaceAll('{n}', user.fullName)
              : context
                  .t('admin.role_confirm_user')
                  .replaceAll('{n}', user.fullName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(context.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    makeAdmin ? AppColors.success : AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.t('common.confirm')),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busyId = user.id);
    try {
      await _api.setRole(user.id, makeAdmin ? 'admin' : 'user');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(makeAdmin
                ? context.t('admin.role_promoted')
                : context.t('admin.role_demoted'))),
      );
      _listKey.currentState?.reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search.controller,
            decoration: InputDecoration(
              hintText: context.t('admin.users_search'),
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: RemoteView<List<AdminUser>>(
            key: _listKey,
            load: () => _api.listUsers(
                query: _search.query.isEmpty ? null : _search.query),
            isEmpty: (l) => l.isEmpty,
            emptyMessage: context.t('admin.users_empty'),
            emptyIcon: Icons.person_search_outlined,
            builder: (context, users) => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _UserCard(
                user: users[i],
                busy: _busyId == users[i].id,
                isSelf: users[i].id == context.read<AuthState>().user?.id,
                onToggleAdmin: () => _toggleRole(users[i], !users[i].isAdmin),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AdminUser user;
  final bool busy;
  final bool isSelf;
  final VoidCallback onToggleAdmin;
  const _UserCard({
    required this.user,
    required this.busy,
    required this.isSelf,
    required this.onToggleAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: user.isAdmin ? AppColors.navy : AppColors.surface,
            foregroundColor: user.isAdmin ? Colors.white : AppColors.textMuted,
            child: Text(
              user.fullName.isNotEmpty
                  ? user.fullName.substring(0, 1).toUpperCase()
                  : '?',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                    if (user.isAdmin) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('ADMIN',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text('(${context.t('admin.you')})',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.phone == null || user.phone!.isEmpty ? '-' : user.phone!,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${context.t('admin.sent')} ${user.sentReports} · ${context.t('admin.solved')} ${user.solvedReports}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.blue),
            )
          else if (isSelf)
            const Icon(Icons.lock_outline, color: AppColors.border)
          else
            OutlinedButton(
              onPressed: onToggleAdmin,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 36),
                side: BorderSide(
                    color: user.isAdmin ? AppColors.danger : AppColors.success),
                foregroundColor:
                    user.isAdmin ? AppColors.danger : AppColors.success,
              ),
              child: Text(
                user.isAdmin
                    ? context.t('admin.demote')
                    : context.t('admin.promote'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
