import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../widgets/animations.dart';
import '../widgets/app_logo.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _pages = [
    _OnbData(
      icon: Icons.warning_amber_rounded,
      title: 'Your Voice Builds the City',
      body: 'Report road issues, broken infrastructure, and public hazards in seconds.',
    ),
    _OnbData(
      icon: Icons.location_on_outlined,
      title: 'Pin the Exact Spot',
      body: 'Attach a photo and your GPS location so crews know exactly where to look.',
    ),
    _OnbData(
      icon: Icons.timeline_outlined,
      title: 'Track Every Update',
      body: 'Follow your report from submission to resolution with real-time status.',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      Navigator.of(context).push(subtleRoute(const RegisterScreen()));
    }
  }

  void _skip() {
    Navigator.of(context).pushReplacement(subtleRoute(const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: TextButton(
                  onPressed: _skip,
                  child: const Text('Skip',
                      style: TextStyle(
                          color: AppColors.muted, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _OnbPage(data: _pages[i], isFirst: i == 0),
              ),
            ),
            _Dots(count: _pages.length, index: _page),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: PressableScale(
                      onTap: () => Navigator.of(context).push(subtleRoute(const LoginScreen())),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.ink),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: const Text('Sign In',
                            style: TextStyle(
                                color: AppColors.ink, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PressableScale(
                      onTap: _next,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_page == _pages.length - 1 ? 'Get Started' : 'Next',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward,
                                color: AppColors.safety, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OnbData {
  final IconData icon;
  final String title;
  final String body;
  const _OnbData({required this.icon, required this.title, required this.body});
}

class _OnbPage extends StatelessWidget {
  final _OnbData data;
  final bool isFirst;
  const _OnbPage({required this.data, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    // First page leads with the brand sign tile; the others use a matching
    // ink-on-safety tile so the whole set reads as one family.
    final mark = isFirst
        ? const AppLogoMark(size: 92, iconSize: 56)
        : Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppColors.safety,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(data.icon, color: AppColors.ink, size: 44),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mark,
          const SizedBox(height: 36),
          Text(data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.ink, fontSize: 24, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 16),
          Text(data.body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 6,
          width: active ? 26 : 6,
          decoration: BoxDecoration(
            color: active ? AppColors.ink : AppColors.line,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
