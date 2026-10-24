import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../money.dart';
import 'states.dart';

/// One bid in the live feed: "@username  ₺1.250". Slides in from the left
/// when it appears (fades only with reduced motion). Sits on the video, so
/// it is a blurred pill for legibility.
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

  /// The signed-in user's own bid: "Sen", in full colour.
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
    final scheme = Theme.of(context).colorScheme;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: AppCurves.enter,
    );
    final row = BlurredPanel(
      borderRadius: AppRadius.pillAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.m,
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
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                  fontWeight: widget.isMine ? FontWeight.w800 : null,
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
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant,
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
