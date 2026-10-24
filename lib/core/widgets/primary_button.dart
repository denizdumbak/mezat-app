import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import 'app_loader.dart';

/// The one main action of a screen: the accent, a full-width pill, at least
/// 48 dp high
/// ([PrimaryButton.bid] is 56 dp). Shows [AppLoader] and ignores taps while
/// [busy]; disabled when [onPressed] is null.
class PrimaryButton extends StatefulWidget {
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
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    // A slight press-in instead of a big splash; skipped with reduced motion.
    final scale = _pressed && enabled && motionAllowed(context) ? 0.98 : 1.0;
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: scale,
        duration: AppDurations.press,
        curve: _pressed ? AppCurves.enter : AppCurves.exit,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: FilledButton(
            onPressed: enabled ? widget.onPressed : null,
            child: widget.busy
                ? const AppLoader()
                : Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ),
      ),
    );
  }
}
