import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../core/strings.dart';
import '../../core/locale_state.dart';
import '../../core/theme.dart';
import '../../data/api/notification_api.dart';
import '../../state/auth_state.dart';
import '../admin/admin_shell.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../reports/my_reports_screen.dart';
import '../reports/submit_report_screen.dart';
import '../widgets/animations.dart';
import 'home_screen.dart';

// Landing shell after login/splash: admins on the web build land in the
// F5 dashboard; everyone else (and all mobile sessions) gets the citizen
// tabs. The backend independently rejects non-admin JWTs on /api/admin.
Widget resolveHomeShell(BuildContext context) {
  final user = context.read<AuthState>().user;
  if (kIsWeb && user?.role == 'admin') return const AdminShell();
  return const MainShell();
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // +1 when moving right across tabs, -1 when moving left. Used by the tab
  // body's AnimatedSwitcher so new pages slide in from the side the user is
  // heading toward (and the Home "Report an issue" button, which also calls
  // goTo, gets the same slide).
  double _navDirection = 1;

  final _pages = const [
    HomeScreen(),
    SubmitReportScreen(),
    MyReportsScreen(),
    ProfileScreen(),
  ];

  // The notification bell lives in the shell (not a page) so it sits in a
  // fixed spot above the bottom bar and never animates with page switches.
  // It is only shown on the My Reports and Profile tabs. The unread badge
  // refreshes on a short timer so it stays current without an app restart.
  final _notifApi = NotificationApi();
  int _unread = 0;
  Timer? _unreadTimer;

  @override
  void initState() {
    super.initState();
    _loadUnread();
    _unreadTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _loadUnread());
  }

  @override
  void dispose() {
    _unreadTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final unread = await _notifApi.unreadCount();
      if (!mounted || unread == _unread) return;
      setState(() => _unread = unread);
    } catch (_) {
      // Badge is best-effort; keep the last known count on failure.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      instantRoute(const NotificationsScreen()),
    );
    if (!mounted) return;
    // Returning usually means something was marked read.
    await _loadUnread();
  }

  void _setIndex(int i) {
    if (i == _index) return;
    setState(() {
      _navDirection = i > _index ? 1.0 : -1.0;
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainShellScope(
      goTo: _setIndex,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _confirmExit(context);
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) {
                    final curved = CurvedAnimation(
                        parent: anim, curve: Curves.easeOutCubic);
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: Offset(_navDirection, 0),
                                end: Offset.zero)
                            .animate(curved),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: _pages[_index],
                  ),
                ),
              ),
              // Fixed above the bottom bar, outside the AnimatedSwitcher so
              // it never slides/fades on tab changes. Shown on Home, My
              // Reports and Profile (every tab except Submit Report).
              if (_index != 1)
                SafeArea(
                  top: false,
                  child: Align(
                    alignment: AlignmentDirectional.bottomEnd,
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.only(bottom: 16, end: 14),
                      child: _NotificationButton(
                        count: _unread,
                        onTap: _openNotifications,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: _BottomBar(index: _index, onTap: _setIndex),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(ctx.t('app.exit_title'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          ctx.t('app.exit_message'),
          style: const TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
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
    if (leave == true) SystemNavigator.pop();
  }
}

class _NotificationButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _NotificationButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.t('notif.title'),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            // Painted road-button treatment, like the report FAB: safety
            // yellow disc with a black bell, floating above the bottom bar.
            color: AppColors.safety,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(Icons.notifications_none,
                    color: AppColors.ink, size: 22),
              ),
              if (count > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShellScope extends InheritedWidget {
  final ValueChanged<int> goTo;
  const MainShellScope({super.key, required this.goTo, required super.child});

  static MainShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShellScope>();

  @override
  bool updateShouldNotify(MainShellScope old) => goTo != old.goTo;
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Keep the nav bar's layout fixed in LTR even when the app locale is
    // Arabic (RTL), so items keep their positions while labels still
    // translate.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  label: context.t('nav.home'),
                  active: index == 0,
                  onTap: () => onTap(0),
                ),
                _ReportFab(active: index == 1, onTap: () => onTap(1)),
                _NavItem(
                  icon: Icons.description_outlined,
                  label: context.t('nav.my_reports'),
                  active: index == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  label: context.t('nav.profile'),
                  active: index == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.watch<LocaleState>().isArabic;
    return PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? AppColors.ink : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            // A3: the 10px label is intentionally tiny; cap how much system
            // text scaling can inflate it so it never overflows the 70px tab.
            // Arabic labels may wrap onto a second line instead of being
            // ellipsized mid-word (e.g. "الملف الشخصي").
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: isArabic ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isArabic ? 9 : 10,
                  height: isArabic ? 1.2 : null,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? AppColors.ink : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // The active tab gets a short safety-yellow underline, like a
            // painted road marking.
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: active ? 22 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.safety,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportFab extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _ReportFab({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutBack,
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              // The report button is a painted road button: safety yellow
              // with an asphalt plus sign.
              color: AppColors.safety,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 320),
              turns: active ? 0.125 : 0,
              child: const Icon(Icons.add, color: AppColors.ink, size: 26),
            ),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (ctx) => MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(ctx.t('nav.report'),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
