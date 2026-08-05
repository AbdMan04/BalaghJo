import 'package:flutter/material.dart';

// iOS/Android-style horizontal slide, applied to every MaterialPageRoute
// via PageTransitionsTheme. The incoming page enters from the right while
// the page underneath shifts slightly left and dims, so forward/back
// navigation reads as motion in one direction.
class HorizontalSlideTransitionsBuilder extends PageTransitionsBuilder {
  const HorizontalSlideTransitionsBuilder();

  static final _incoming =
      Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero);
  static final _outgoing =
      Tween<Offset>(begin: Offset.zero, end: const Offset(-0.22, 0.0));
  static final _underDim = Tween<double>(begin: 1.0, end: 0.6);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The page being pushed slides in from the right.
    final incoming = SlideTransition(
      position: _incoming.animate(
        CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      ),
      child: child,
    );
    // The page underneath (secondaryAnimation drives it while it is covered)
    // slides a little further left and dims for depth.
    return FadeTransition(
      opacity: _underDim.animate(secondaryAnimation),
      child: SlideTransition(
        position: _outgoing.animate(
          CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic),
        ),
        child: incoming,
      ),
    );
  }
}
