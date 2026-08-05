import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../home/main_shell.dart';
import '../widgets/animations.dart';
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
      next = const MainShell();
    }
    Navigator.of(context).pushReplacement(pageRoute(next));
  }

  @override
  void dispose() {
    _logo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.navy,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _logo,
                  builder: (_, __) {
                    return Transform.scale(
                      scale: _scale.value,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sky.withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Hero(
                          tag: 'app-logo',
                          child: Icon(Icons.location_on, color: Colors.white, size: 64),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _fade,
                  child: const Column(
                    children: [
                      Text('BALAGHJO',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 5)),
                      SizedBox(height: 8),
                      Text('بلِّغ · سجِّل · غيِّر',
                          style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                FadeTransition(
                  opacity: _fade,
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
