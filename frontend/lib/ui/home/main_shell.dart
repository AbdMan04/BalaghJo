import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../admin/admin_shell.dart';
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
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              final curved =
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                          begin: Offset(_navDirection, 0), end: Offset.zero)
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
          bottomNavigationBar: _BottomBar(index: _index, onTap: _setIndex),
        ),
      ),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text(ctx.t('app.exit_title'), style: const TextStyle(fontWeight: FontWeight.w800)),
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
                    child: Text(ctx.t('app.no'), style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700)),
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
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: Text(ctx.t('app.yes'), style: const TextStyle(fontWeight: FontWeight.w800)),
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
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: context.t('nav.home'),
                  active: index == 0,
                  onTap: () => onTap(0),
                ),
                _ReportFab(active: index == 1, onTap: () => onTap(1)),
                _NavItem(
                  icon: Icons.description_outlined,
                  activeIcon: Icons.description,
                  label: context.t('nav.my_reports'),
                  active: index == 2,
                  onTap: () => onTap(2),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
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
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              width: active ? 32 : 0,
              height: 3,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Icon(
                active ? activeIcon : icon,
                key: ValueKey(active),
                color: active ? AppColors.blue : AppColors.textMuted,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            // A3: the 10px label is intentionally tiny; cap how much system
            // text scaling can inflate it so it never overflows the 70px tab.
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.blue : AppColors.textMuted,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
              color: AppColors.calmBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.blue.withValues(alpha: active ? 0.55 : 0.3),
                  blurRadius: active ? 20 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 320),
              turns: active ? 0.125 : 0,
              child: const Icon(Icons.add, color: Colors.white, size: 26),
            ),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (ctx) => MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.3,
              child: Text(ctx.t('nav.report'),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }
}
