// AdminShell — F5 (Admin Dashboard) landing shell for role=admin users
// on the Flutter web build. Hosts the four dashboard sections (Overview,
// Reports, Announcements, Users) behind a left navigation rail; role
// gating is enforced upstream (splash/routing) and the backend rejects
// non-admin JWTs on every admin route anyway.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
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

  static const _titles = ['admin.nav_overview', 'admin.nav_reports', 'admin.nav_announcements', 'admin.nav_users'];

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
                            color: AppColors.navy, fontWeight: FontWeight.w700)),
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
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.location_on, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('BALAGHJO',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
            const SizedBox(width: 8),
            Text(
              context.t('admin.badge'),
              style: const TextStyle(
                color: AppColors.blue,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                context.t(_titles[_index]),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('profile.log_out'),
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            backgroundColor: Colors.white,
            selectedIconTheme:
                const IconThemeData(color: AppColors.navy, size: 22),
            unselectedIconTheme:
                const IconThemeData(color: AppColors.textMuted, size: 22),
            selectedLabelTextStyle: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 11),
            unselectedLabelTextStyle: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 11),
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.space_dashboard_outlined),
                selectedIcon: const Icon(Icons.space_dashboard),
                label: Text(context.t('admin.nav_overview')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.assignment_outlined),
                selectedIcon: const Icon(Icons.assignment),
                label: Text(context.t('admin.nav_reports')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.campaign_outlined),
                selectedIcon: const Icon(Icons.campaign),
                label: Text(context.t('admin.nav_announcements')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: Text(context.t('admin.nav_users')),
              ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
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
    );
  }
}
