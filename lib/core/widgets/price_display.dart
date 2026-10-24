import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../money.dart';

/// Shows an amount; when it changes, each changed character rolls up into
/// place (prices only go up during an auction). With reduced motion the
/// characters cross-fade instead.
class PriceDisplay extends StatelessWidget {
  const PriceDisplay({
    super.key,
    required this.amount,
    this.style = AppTextStyles.priceDisplay,
  });

  final Money amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final text = amount.format();
    final chars = text.characters.toList();
    final motion = motionAllowed(context);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: ClipRect(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < chars.length; i++)
              // Keyed by position from the right, so "₺999" -> "₺1.000"
              // keeps the units digit in the same slot.
              _RollingChar(
                key: ValueKey(chars.length - i),
                char: chars[i],
                style: style,
                motion: motion,
              ),
          ],
        ),
      ),
    );
  }
}

class _RollingChar extends StatelessWidget {
  const _RollingChar({
    super.key,
    required this.char,
    required this.style,
    required this.motion,
  });

  final String char;
  final TextStyle style;
  final bool motion;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppDurations.price,
      switchInCurve: AppCurves.enter,
      switchOutCurve: AppCurves.exit,
      transitionBuilder: (child, animation) {
        if (!motion) return FadeTransition(opacity: animation, child: child);
        // The new character comes up from below; the old one (whose
        // animation runs in reverse) leaves upwards.
        final incoming = child.key == ValueKey(char);
        final offset = Tween<Offset>(
          begin: Offset(0, incoming ? 1 : -1),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: offset,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(char, key: ValueKey(char), style: style),
    );
  }
}
