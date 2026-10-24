import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';

/// Gives every [SkeletonBox] below it a light sweeping across, the loading
/// state of lists (instead of a spinner). With reduced motion the boxes stay
/// still.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppDurations.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (motionAllowed(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yükleniyor',
      child: ExcludeSemantics(
        child: _ShimmerScope(
          animation: motionAllowed(context) ? _controller : null,
          child: widget.child,
        ),
      ),
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({required this.animation, required super.child});

  final Animation<double>? animation;

  static Animation<double>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;

  @override
  bool updateShouldNotify(_ShimmerScope old) => animation != old.animation;
}

/// A grey block where content will be: the panel colour, with the light of
/// the nearest [Shimmer] passing over it.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = AppRadius.imageAll,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = context.palette.panel;
    final light = Theme.of(context).colorScheme.surface;
    final animation = _ShimmerScope.of(context);

    BoxDecoration decoration(double t) => BoxDecoration(
      borderRadius: borderRadius,
      color: animation == null ? base : null,
      gradient: animation == null
          ? null
          : LinearGradient(
              colors: [base, light, base],
              stops: const [0.35, 0.5, 0.65],
              transform: _Slide(t),
            ),
    );

    final box = animation == null
        ? DecoratedBox(decoration: decoration(0))
        : AnimatedBuilder(
            animation: animation,
            builder: (context, _) =>
                DecoratedBox(decoration: decoration(animation.value)),
          );
    return SizedBox(width: width, height: height, child: box);
  }
}

/// Moves the gradient from one box-width left of the box to one right of it.
class _Slide extends GradientTransform {
  const _Slide(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (2 * t - 1), 0, 0);
}
