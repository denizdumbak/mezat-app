import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import 'app_loader.dart';

/// The one main action of a screen: the accent, a full-width pill, at least
/// 48 dp high
/// ([PrimaryButton.bid] is 56 dp). Shows [AppLoader] and ignores taps while
/// [busy]; disabled when [onPressed] is null.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  }) : height = AppSize.touch;

  /// The bid button on the live screen.
  const PrimaryButton.bid({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  }) : height = AppSize.bidButton;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return _PressScale(
      enabled: enabled,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          child: busy
              ? const AppLoader()
              : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// The quieter choice next to a [PrimaryButton] (Vazgeç, Hayır, Limiti
/// artır): the same full-width pill, filled one tone lighter than the surface
/// instead of the accent, so it still reads as a button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      enabled: onPressed != null,
      child: SizedBox(
        height: AppSize.touch,
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.secondaryFill,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: onPressed,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// A slight press-in instead of a big splash; skipped with reduced motion.
class _PressScale extends StatefulWidget {
  const _PressScale({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed && widget.enabled && motionAllowed(context)
        ? 0.98
        : 1.0;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: scale,
        duration: AppDurations.press,
        curve: _pressed ? AppCurves.enter : AppCurves.exit,
        child: widget.child,
      ),
    );
  }
}
