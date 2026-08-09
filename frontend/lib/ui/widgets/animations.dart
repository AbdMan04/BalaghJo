import 'package:flutter/material.dart';

// FadeSlideIn — legacy entrance animation (fade + slide-up from the bottom
// with a stagger delay). The app now displays data naturally and directly,
// so this renders its child immediately with no animation. The parameters
// are kept so existing call sites keep compiling unchanged.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 24,
  });

  @override
  Widget build(BuildContext context) => child;
}

class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// [scale] is how far the control shrinks on press.
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  // Fast press-down (90ms easeOut), then a springy release (240ms, easeOut
  // overshoots slightly so the control bounces back).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 240),
    lowerBound: 0,
    upperBound: 1,
  );
  late final Animation<double> _pressed = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // GestureDetector is invisible to screen readers on its own, so
    // expose this as a tappable button. The child's own text/icon
    // provides the semantic label; disabled controls are announced as
    // such and skipped by TalkBack/VoiceOver.
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      child: GestureDetector(
        onTapDown: widget.onTap == null ? null : (_) => _c.forward(),
        onTapUp: widget.onTap == null ? null : (_) => _c.reverse(),
        onTapCancel: widget.onTap == null ? null : () => _c.reverse(),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _pressed,
          builder: (_, child) => Transform.scale(
            scale: 1 - (1 - widget.scale) * _pressed.value,
            child: child!,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final Duration duration;
  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text(v.toInt().toString(), style: style),
    );
  }
}

class ShakeWidget extends StatefulWidget {
  final Widget child;
  final Listenable trigger;
  const ShakeWidget({super.key, required this.child, required this.trigger});

  @override
  State<ShakeWidget> createState() => _ShakeWidgetState();
}

class _ShakeWidgetState extends State<ShakeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_shake);
  }

  void _shake() {
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_shake);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        final dx = t == 0 ? 0.0 : 8 * (1 - t) * (t * 12 % 2 < 1 ? 1 : -1);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}

// Builds every route as a MaterialPageRoute so the transition is owned by
// the app-wide PageTransitionsTheme (horizontal slide) instead of each
// call site. Kept as a helper so call sites read as one line.
Route<T> pageRoute<T>(Widget page, {bool fullscreenDialog = false}) {
  return MaterialPageRoute<T>(
    fullscreenDialog: fullscreenDialog,
    builder: (_) => page,
  );
}

// Builds a route that switches instantly with no transition — used for the
// data-display flow (report lists/details, map, notifications) so those
// screens appear directly, like switching bottom-nav tabs.
Route<T> instantRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, __, ___) => page,
  );
}

// Subtle entrance for the auth screens (splash -> onboarding -> sign in /
// sign up): a soft fade with a slight upward drift suggests forward
// movement without the full horizontal slide.
Route<T> subtleRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class SkeletonBox extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFE7E1D5),
            const Color(0xFFF1ECE2),
            _c.value,
          ),
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class GradientBlob extends StatefulWidget {
  final Color color;
  final double size;
  const GradientBlob({super.key, required this.color, this.size = 220});

  @override
  State<GradientBlob> createState() => _GradientBlobState();
}

class _GradientBlobState extends State<GradientBlob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(20 * _c.value, -20 * _c.value),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [widget.color.withValues(alpha: 0.55), widget.color.withValues(alpha: 0)],
              ),
            ),
          ),
        );
      },
    );
  }
}
