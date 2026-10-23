import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../core/time_format.dart';

/// The auction's photo, or a calm placeholder when there is none.
class AuctionPhoto extends StatelessWidget {
  const AuctionPhoto({
    super.key,
    required this.imageUrl,
    required this.aspectRatio,
    this.borderRadius = AppRadius.largeAll,
    this.overlay,
  });

  final String? imageUrl;
  final double aspectRatio;
  final BorderRadius borderRadius;

  /// Drawn on top, e.g. the live badge.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final placeholder = ColoredBox(
      color: AppColors.stageRaised,
      child: Center(
        child: Icon(
          Icons.photo_outlined,
          color: AppColors.onStageMuted,
          size: AppSize.touch,
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null)
              placeholder
            else
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
            ?overlay,
          ],
        ),
      ),
    );
  }
}

/// The gold dot that means "live", without the label.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: AppSpace.s,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.gold,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// "● CANLI" on a dimmed pill, for photos and the live screen.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return _Pill(
      children: [
        const LiveDot(),
        const SizedBox(width: AppSpace.xs),
        Text(
          'CANLI',
          style: Theme.of(
            context,
          ).textTheme.labelSmall!.copyWith(color: AppColors.gold),
        ),
      ],
    );
  }
}

/// Eye icon and a short viewer count.
class ViewerCount extends StatelessWidget {
  const ViewerCount({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    // No count yet (presence arrives with the video in M4): show nothing
    // rather than a discouraging "0".
    if (count <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$count izleyici',
      excludeSemantics: true,
      child: _Pill(
        children: [
          const Icon(
            Icons.visibility_outlined,
            size: AppSize.iconSmall,
            color: AppColors.onStage,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            formatCount(count),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: AppColors.onStage,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.scrim,
        borderRadius: AppRadius.smallAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s,
          vertical: AppSpace.xs,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// A round avatar with the first letter of the username.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar({
    super.key,
    required this.username,
    this.size = AppSize.avatar,
  });

  /// Letter height relative to the circle.
  static const _initialScale = 0.42;

  final String username;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = username.isEmpty ? '?' : username.characters.first;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.stageRaised,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line, width: AppSize.line),
        ),
        child: Center(
          child: Text(
            initial.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontSize: size * _initialScale,
              color: AppColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}
