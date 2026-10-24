import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/time_format.dart';

/// The auction's photo, the strongest thing on every screen. [imageUrl] is a
/// network URL or an `assets/` path (the demo's bundled photos). Without
/// one, or when it fails to load, a calm placeholder: the secondary surface
/// with the first letter of [label].
class AuctionPhoto extends StatelessWidget {
  const AuctionPhoto({
    super.key,
    required this.imageUrl,
    required this.aspectRatio,
    this.label = '',
    this.borderRadius = AppRadius.imageAll,
    this.overlay,
  });

  final String? imageUrl;
  final double aspectRatio;

  /// Usually the auction's title; its first letter fills the placeholder.
  final String label;
  final BorderRadius borderRadius;

  /// Drawn on top, e.g. the live badge.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final initial = label.trim().isEmpty
        ? ''
        : label.trim().characters.first.toUpperCase();
    final placeholder = ColoredBox(
      key: const Key('auctionPhoto.placeholder'),
      color: context.palette.panel,
      child: Center(
        child: ExcludeSemantics(
          child: Text(
            initial,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
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
            else if (url.startsWith('assets/'))
              Image.asset(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              )
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

/// The live red dot that means "live", without the label.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, this.color});

  /// Defaults to the live colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: AppSpace.s,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? context.palette.live,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// "● CANLI" on a live red pill, for photos and the live screen; with a
/// [viewerCount] above zero, "● CANLI · 236".
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.viewerCount = 0});

  final int viewerCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return OverlayPill(
      color: palette.live,
      children: [
        LiveDot(color: palette.onOverlay),
        const SizedBox(width: AppSpace.xs),
        Text(
          viewerCount > 0 ? 'CANLI · ${formatCount(viewerCount)}' : 'CANLI',
          style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: palette.onOverlay,
            fontWeight: FontWeight.w800,
            fontFeatures: AppFonts.tabular,
          ),
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
    final onOverlay = context.palette.onOverlay;
    return Semantics(
      label: '$count izleyici',
      excludeSemantics: true,
      child: OverlayPill(
        children: [
          Icon(
            Icons.visibility_outlined,
            size: AppSize.iconSmall,
            color: onOverlay,
          ),
          const SizedBox(width: AppSpace.xs),
          Text(
            formatCount(count),
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: onOverlay,
              fontWeight: FontWeight.w700,
              fontFeatures: AppFonts.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill on a photo or the video: the dark overlay unless [color].
class OverlayPill extends StatelessWidget {
  const OverlayPill({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? context.palette.overlay,
        borderRadius: AppRadius.pillAll,
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
          color: context.palette.panel,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initial.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontSize: size * _initialScale,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
