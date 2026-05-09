import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../home/main_shell.dart';
import '../widgets/animations.dart';
import 'onboarding_screen.dart';
import 'verification_screen.dart';

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

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

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
    } else if (auth.user?.isVerified == false) {
      next = const VerificationScreen();
    } else {
      next = const MainShell();
    }
    Navigator.of(context).pushReplacement(fadeSlideRoute(next));
  }

  @override
  void dispose() {
    _logo.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.navy, Color(0xFF112A55), Color(0xFF1B4FD8)],
              ),
            ),
          ),
          const Positioned(top: -60, left: -40, child: GradientBlob(color: AppColors.sky, size: 280)),
          const Positioned(bottom: -80, right: -60, child: GradientBlob(color: AppColors.blue, size: 320)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_logo, _pulse]),
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
                              color: AppColors.sky.withValues(alpha: 0.4 + 0.3 * _pulse.value),
                              blurRadius: 30 + 20 * _pulse.value,
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
                      Text('بلغ · سجل · غير',
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
