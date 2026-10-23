import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../money.dart';

/// One bid in the live feed: "@username  ₺1.250". Slides in from the left
/// when it appears (fades only with reduced motion). Sits on the video, so
/// it has its own dimmed background for legibility.
class BidFeedRow extends StatefulWidget {
  const BidFeedRow({
    super.key,
    required this.username,
    required this.amount,
    this.isMine = false,
    this.isLeading = false,
  });

  final String username;
  final Money amount;

  /// The signed-in user's own bid: name in gold.
  final bool isMine;

  /// The current highest bid: amount in full colour, others muted.
  final bool isLeading;

  @override
  State<BidFeedRow> createState() => _BidFeedRowState();
}

class _BidFeedRowState extends State<BidFeedRow>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppDurations.entry,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: AppCurves.enter,
    );
    final row = DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.scrim,
        borderRadius: AppRadius.smallAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s,
          vertical: AppSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.isMine ? 'Sen' : '@${widget.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium!.copyWith(
                  color: widget.isMine
                      ? AppColors.gold
                      : AppColors.onStageMuted,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s),
            Text(
              widget.amount.format(),
              style: text.labelMedium!.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: AppFonts.tabular,
                color: widget.isLeading
                    ? AppColors.onStage
                    : AppColors.onStageMuted,
              ),
            ),
          ],
        ),
      ),
    );

    final faded = FadeTransition(opacity: animation, child: row);
    if (!motionAllowed(context)) return faded;
    return SlideTransition(
      position: Tween(
        begin: const Offset(-0.2, 0),
        end: Offset.zero,
      ).animate(animation),
      child: faded,
    );
  }
}
