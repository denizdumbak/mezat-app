import 'package:flutter/material.dart';

/// The app's loading indicator: three dots that fade in turn, in the
/// secondary text colour unless [color] is given. Used instead of Material's
/// spinner. Opacity only, so it behaves the same with reduced motion.
class AppLoader extends StatefulWidget {
  const AppLoader({super.key, this.color, this.dotSize = 6});

  final Color? color;
  final double dotSize;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  // One cycle: each dot gets a third of it to light up.
  static const _cycle = Duration(milliseconds: 900);

  late final _controller = AnimationController(vsync: this, duration: _cycle)
    ..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      label: 'Yükleniyor',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.dotSize / 3),
                child: Opacity(
                  opacity: _opacityFor(i),
                  child: SizedBox.square(
                    dimension: widget.dotSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _opacityFor(int dot) {
    // Distance of this dot's slot from the moving highlight, wrapped 0..1.
    final phase = (_controller.value - dot / 3) % 1;
    return phase < 1 / 3 ? 1 : 0.3;
  }
}
