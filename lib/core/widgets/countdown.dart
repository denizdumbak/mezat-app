import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../auction_rules.dart';

/// Remaining time until [endsAt], updated every second. Display only: the
/// server decides when an auction ends.
///
/// In the last [urgentBelow] (the anti-sniping window: a bid now moves the
/// end) the digits turn the live colour. When
/// [endsAt] moves later (a last-second bid extended the auction), a
/// "+30 sn" chip shows the extension for a moment.
class Countdown extends StatefulWidget {
  const Countdown({
    super.key,
    required this.endsAt,
    this.clock = DateTime.now,
    this.urgentBelow = antiSnipingWindow,
    this.style = AppTextStyles.timer,
  });

  final DateTime endsAt;

  /// Injected so tests control the time.
  final DateTime Function() clock;
  final Duration urgentBelow;
  final TextStyle style;

  @override
  State<Countdown> createState() => _CountdownState();
}

/// How long the extension chip stays visible.
const extensionChipVisible = Duration(seconds: 2);

class _CountdownState extends State<Countdown> {
  late final Timer _ticker;
  Timer? _chipTimer;
  Duration? _extendedBy;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(Countdown old) {
    super.didUpdateWidget(old);
    // A real extension is whole seconds; a new snapshot of the same end a
    // few milliseconds later is not one.
    if (widget.endsAt.difference(old.endsAt) >= const Duration(seconds: 1)) {
      _extendedBy = widget.endsAt.difference(old.endsAt);
      _chipTimer?.cancel();
      _chipTimer = Timer(extensionChipVisible, () {
        if (mounted) setState(() => _extendedBy = null);
      });
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _chipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.endsAt.difference(widget.clock());
    final remaining = left.isNegative ? Duration.zero : left;
    final urgent = remaining <= widget.urgentBelow;
    final text = formatRemaining(remaining);
    final extendedBy = _extendedBy;

    return Semantics(
      label: 'Kalan süre $text',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: AppDurations.price,
            curve: AppCurves.enter,
            // Merged onto the surrounding style, so the digits keep the
            // theme's text colour until they turn live red.
            style: DefaultTextStyle.of(context).style
                .merge(widget.style)
                .copyWith(color: urgent ? context.palette.live : null),
            child: Text(text),
          ),
          AnimatedSwitcher(
            duration: AppDurations.extend,
            switchInCurve: AppCurves.enter,
            switchOutCurve: AppCurves.exit,
            transitionBuilder: (child, animation) => motionAllowed(context)
                ? ScaleTransition(
                    scale: Tween(begin: 0.8, end: 1.0).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  )
                : FadeTransition(opacity: animation, child: child),
            child: extendedBy == null
                ? const SizedBox.shrink()
                : Padding(
                    key: ValueKey(widget.endsAt),
                    padding: const EdgeInsets.only(left: AppSpace.s),
                    child: ExtensionChip(extendedBy: extendedBy),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "+30 sn": shows how much a late bid extended the auction.
class ExtensionChip extends StatelessWidget {
  const ExtensionChip({super.key, required this.extendedBy});

  final Duration extendedBy;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color, width: AppSize.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s,
          vertical: AppSpace.xs,
        ),
        child: Text(
          '+${extendedBy.inSeconds} sn',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            fontFeatures: AppFonts.tabular,
          ),
        ),
      ),
    );
  }
}

/// "04:09", or "1:02:03" from an hour up.
String formatRemaining(Duration remaining) {
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  final seconds = remaining.inSeconds % 60;
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}
