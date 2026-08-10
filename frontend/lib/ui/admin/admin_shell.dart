// AdminShell — F5 (Admin Dashboard) landing shell for role=admin users
// on the Flutter web build. Crafted as an "operations board": an asphalt
// sidebar carries the brand, nav and the signed-in admin; the workspace
// header titles the active section. The four tabs keep their own state
// and polling behind an IndexedStack; role gating is enforced upstream
// (splash/routing) and the backend rejects non-admin JWTs anyway.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/locale_state.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../auth/onboarding_screen.dart';
import '../widgets/animations.dart';
import 'admin_announcements_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  bool _wasAuthenticated = true;
  bool _manualLogout = false;

  static const _titles = [
    'admin.nav_overview',
    'admin.nav_reports',
    'admin.nav_announcements',
    'admin.nav_users'
  ];

  static const _nav = <(IconData, IconData, String)>[
    (
      Icons.space_dashboard_outlined,
      Icons.space_dashboard,
      'admin.nav_overview'
    ),
    (Icons.assignment_outlined, Icons.assignment, 'admin.nav_reports'),
    (Icons.campaign_outlined, Icons.campaign, 'admin.nav_announcements'),
    (Icons.people_outline, Icons.people_outlined, 'admin.nav_users'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<AuthState>().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    context.read<AuthState>().removeListener(_onAuthChanged);
    super.dispose();
  }

  // A lost session (expired/revoked token or manual logout) has to land the
  // admin back on sign-in — the dashboard has no useful state without a JWT.
  // Runs from AuthState notifications (manual logout clears the session the
  // same way expiry does), so navigation lives here, not in the button.
  void _onAuthChanged() {
    final auth = context.read<AuthState>();
    final authenticated = auth.isAuthenticated;
    if (_wasAuthenticated && !authenticated && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final warn = !_manualLogout;
      _manualLogout = false;
      Navigator.of(context).pushAndRemoveUntil(
          pageRoute(const OnboardingScreen()), (_) => false);
      if (warn) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(content: Text(context.t('admin.session_expired'))),
        );
      }
    }
    _wasAuthenticated = authenticated;
  }

  Future<void> _confirmLogout() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(ctx.t('profile.logout_title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(ctx.t('profile.logout_confirm'),
            style: const TextStyle(color: AppColors.textMuted, height: 1.4)),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(ctx.t('app.no'),
                        style: const TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.ink,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: Text(ctx.t('app.yes'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      _manualLogout = true;
      context.read<AuthState>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 900;
          return Row(
            children: [
              _Sidebar(
                index: _index,
                compact: compact,
                onSelect: (i) => setState(() => _index = i),
                onLogout: _confirmLogout,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WorkspaceHeader(index: _index, compact: compact),
                    const Divider(
                        height: 1, thickness: 1, color: AppColors.line),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: [
                          AdminOverviewScreen(active: _index == 0),
                          AdminReportsScreen(active: _index == 1),
                          const AdminAnnouncementsScreen(),
                          const AdminUsersScreen(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asphalt sidebar: brand on top, nav rail, signed-in admin + logout below.
// Collapses to a compact icon rail below 900px.
// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final int index;
  final bool compact;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.index,
    required this.compact,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthState, AppUser?>((s) => s.user);
    return Semantics(
      container: true,
      label: context.t('admin.nav_overview'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: compact ? 76 : 252,
        color: AppColors.ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                  compact ? 0 : 20, 22, compact ? 0 : 20, 18),
              child: _BrandMark(compact: compact),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    for (var i = 0; i < _AdminShellState._nav.length; i++)
                      _NavItem(
                        icon: _AdminShellState._nav[i].$1,
                        selectedIcon: _AdminShellState._nav[i].$2,
                        label: context.t(_AdminShellState._nav[i].$3),
                        selected: index == i,
                        compact: compact,
                        onTap: () => onSelect(i),
                      ),
                  ],
                ),
              ),
            ),
            _SidebarFooter(user: user, compact: compact, onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  final bool compact;
  const _BrandMark({required this.compact});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.safety,
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Icon(Icons.location_on, color: AppColors.ink, size: 19),
    );
    if (compact) {
      return Center(child: mark);
    }
    return Row(
      children: [
        mark,
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BALAGHJO',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                      fontSize: 14)),
              const SizedBox(height: 2),
              Text(context.t('admin.city'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    final fg = active ? AppColors.ink : Colors.white70;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(
        button: true,
        selected: active,
        label: widget.label,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: widget.compact
                    ? const EdgeInsets.symmetric(vertical: 13)
                    : const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.safety
                      : _hover
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: widget.compact
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Icon(active ? widget.selectedIcon : widget.icon,
                        color: fg, size: 20),
                    if (!widget.compact) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: fg,
                            fontSize: 13.5,
                            fontWeight:
                                active ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final AppUser? user;
  final bool compact;
  final VoidCallback onLogout;
  const _SidebarFooter({
    required this.user,
    required this.compact,
    required this.onLogout,
  });

  String get _initial {
    final name = user?.fullName ?? '';
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 17,
      backgroundColor: AppColors.safety,
      foregroundColor: AppColors.ink,
      child: Text(_initial,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
      child: Column(
        children: [
          const Divider(height: 1, thickness: 1, color: Colors.white12),
          const SizedBox(height: 14),
          if (compact) ...[
            Tooltip(message: user?.fullName ?? '', child: avatar),
            const SizedBox(height: 6),
            IconButton(
              tooltip: context.t('profile.log_out'),
              onPressed: onLogout,
              icon: Icon(Icons.logout_rounded,
                  size: 20, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ] else
            Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        context.t('admin.badge'),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 10,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.t('profile.log_out'),
                  onPressed: onLogout,
                  icon: Icon(Icons.logout_rounded,
                      size: 20, color: Colors.white.withValues(alpha: 0.7)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workspace header: admin badge eyebrow and the active section title.
// ---------------------------------------------------------------------------

class _WorkspaceHeader extends StatelessWidget {
  final int index;
  final bool compact;
  const _WorkspaceHeader({required this.index, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding:
          EdgeInsets.fromLTRB(compact ? 20 : 28, 14, compact ? 20 : 28, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.safety,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.t('admin.badge'),
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  context.t(_AdminShellState._titles[index]),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppColors.ink),
                ),
              ],
            ),
          ),
          const _LanguageToggle(),
        ],
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleState>();
    final isArabic = locale.isArabic;
    return PopupMenuButton<String>(
      tooltip: context.t('admin.language_title'),
      initialValue: isArabic ? 'ar' : 'en',
      onSelected: (value) {
        final state = context.read<LocaleState>();
        final target = value == 'ar' ? const Locale('ar') : const Locale('en');
        if (state.locale == target) return;
        state.setLocale(target);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md)),
            content: Text(context.t('admin.language_updated')),
          ),
        );
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'en',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isArabic)
                const Icon(Icons.check, size: 16, color: AppColors.safety),
              const SizedBox(width: 8),
              Text(ctx.t('admin.language_english')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'ar',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isArabic)
                const Icon(Icons.check, size: 16, color: AppColors.safety),
              const SizedBox(width: 8),
              Text(ctx.t('admin.language_arabic')),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              isArabic
                  ? context.t('admin.language_arabic')
                  : context.t('admin.language_english'),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}
