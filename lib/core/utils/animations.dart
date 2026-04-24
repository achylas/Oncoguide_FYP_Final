import 'package:flutter/material.dart';

class Animations {
  // Fade in with delay
  static Widget fadeIn({required Widget child, required int delay}) {
    return _DelayedAnimation(
      delay: delay,
      child: child,
      type: AnimationType.fade,
    );
  }

  // Slide up with delay
  static Widget slideUp({required Widget child, required int delay}) {
    return _DelayedAnimation(
      delay: delay,
      child: child,
      type: AnimationType.slideUp,
    );
  }
}

// Helper enum
enum AnimationType { fade, slideUp }

// Internal widget to handle delayed animation
class _DelayedAnimation extends StatefulWidget {
  final Widget child;
  final int delay;
  final AnimationType type;

  const _DelayedAnimation({
    required this.child,
    required this.delay,
    required this.type,
  });

  @override
  State<_DelayedAnimation> createState() => _DelayedAnimationState();
}

class _DelayedAnimationState extends State<_DelayedAnimation>
    with SingleTickerProviderStateMixin {
  double _opacity = 0;
  Offset _offset = const Offset(0, 0.2);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        setState(() {
          _opacity = 1;
          _offset = Offset.zero;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: _opacity,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 500),
        offset: _offset,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
