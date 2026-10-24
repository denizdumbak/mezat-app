import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../money.dart';

/// The "SATILDI" moment: the stamp drops in and settles with a small shake
/// (~700 ms, once), the phone gives a firm haptic, then the winner appears.
/// With reduced motion the stamp only fades in.
class SoldStamp extends StatefulWidget {
  const SoldStamp({
    super.key,
    required this.winnerUsername,
    required this.amount,
    required this.isMe,
    this.action,
  });

  final String winnerUsername;
  final Money amount;

  /// The signed-in user won: "Kazandın" in the success colour.
  final bool isMe;

  /// Shown under the winner, e.g. a way back to the list.
  final Widget? action;

  @override
  State<SoldStamp> createState() => _SoldStampState();
}

class _SoldStampState extends State<SoldStamp>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppDurations.sold,
  );
  bool _showWinner = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _controller.forward().whenComplete(() {
      if (mounted) setState(() => _showWinner = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = motionAllowed(context);
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final stamp = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.imageAll,
        border: Border.all(color: palette.success, width: AppSize.stampBorder),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpace.xl,
          vertical: AppSpace.m,
        ),
        child: Text('SATILDI', style: AppTextStyles.stamp),
      ),
    );

    return ColoredBox(
      color: palette.scrimStrong,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  // Fully visible in the first 30 %.
                  final opacity = (t / 0.3).clamp(0.0, 1.0);
                  if (!motion) return Opacity(opacity: opacity, child: child);
                  // Drops from 1.6x to 1x in the first 55 %, then a decaying
                  // shake for the rest.
                  final drop = AppCurves.enter.transform(
                    (t / 0.55).clamp(0, 1),
                  );
                  final scale = 1.6 - 0.6 * drop;
                  final shakeT = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
                  final angle = 0.05 * sin(shakeT * 3 * 2 * pi) * (1 - shakeT);
                  return Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: angle,
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  );
                },
                child: stamp,
              ),
              const SizedBox(height: AppSpace.xl),
              AnimatedOpacity(
                opacity: _showWinner ? 1 : 0,
                duration: AppDurations.entry,
                curve: AppCurves.enter,
                child: Column(
                  children: [
                    Text(
                      widget.isMe ? 'Kazandın' : '@${widget.winnerUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: widget.isMe
                          ? text.headlineSmall!.copyWith(color: palette.success)
                          : text.headlineSmall,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      widget.isMe
                          ? '${widget.amount.format()} ile senin oldu.'
                          : '${widget.amount.format()} ile kazandı.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                    if (widget.action != null) ...[
                      const SizedBox(height: AppSpace.xl),
                      widget.action!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
