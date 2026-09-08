import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../home/main_shell.dart';
import '../widgets/animations.dart';
import '../widgets/app_logo.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _logo,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _logo, curve: const Interval(0, 0.6));

  @override
  void initState() {
    super.initState();
    _logo.forward();
    _go();
  }

  Future<void> _go() async {
    await context.read<AuthState>().bootstrap();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final auth = context.read<AuthState>();
    final Widget next;
    if (!auth.isAuthenticated) {
      next = const OnboardingScreen();
    } else {
      next = resolveHomeShell(context);
    }
    Navigator.of(context).pushReplacement(subtleRoute(next));
  }

  @override
  void dispose() {
    _logo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _logo,
              builder: (_, __) {
                return Transform.scale(
                  scale: _scale.value,
                  child: const Hero(
                    tag: 'app-logo',
                    // The mark is a road-sign tile: safety yellow with an
                    // asphalt pin, echoing the municipal notice-board theme.
                    child: AppLogoMark(size: 92, iconSize: 56),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: _fade,
              child: const Column(
                children: [
                  Text('BALAGHJO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6)),
                  SizedBox(height: 12),
                  // Thin sign rule under the wordmark.
                  SizedBox(
                    width: 40,
                    height: 3,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.safety),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('بلِّغ · سجِّل · غيِّر',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          letterSpacing: 2)),
                ],
              ),
            ),
            const SizedBox(height: 56),
            FadeTransition(
              opacity: _fade,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: AppColors.safety,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
