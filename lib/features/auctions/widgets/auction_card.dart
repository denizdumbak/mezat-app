import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/time_format.dart';
import '../../../core/widgets/countdown.dart';
import '../../../core/widgets/price_label.dart';
import '../../../data/auction_feed_repository.dart';
import 'auction_visuals.dart';

enum AuctionCardVariant { live, upcoming, ended, row }

/// One auction in a list, with the photo leading and the price strongest.
///
/// - [AuctionCard.live]: a tall 3:4 photo with "CANLI · 236" and the time
///   left over a gradient at its foot; below, the seller, the title (two
///   lines at most) and the current bid.
/// - [AuctionCard.upcoming]: a wide photo with the start time and a
///   "Hatırlat" button on it; below, seller, title and opening price.
/// - [AuctionCard.ended]: faded, "Satıldı ₺X".
/// - [AuctionCard.row]: horizontal, a square thumbnail and the details,
///   with an optional [trailing] action (Canlı list, the planned auctions
///   under Yayın aç).
class AuctionCard extends StatelessWidget {
  const AuctionCard.live({super.key, required this.auction, this.onTap})
    : variant = AuctionCardVariant.live,
      onRemind = null,
      trailing = null;

  const AuctionCard.upcoming({
    super.key,
    required this.auction,
    this.onTap,
    this.onRemind,
  }) : variant = AuctionCardVariant.upcoming,
       trailing = null;

  const AuctionCard.ended({super.key, required this.auction, this.onTap})
    : variant = AuctionCardVariant.ended,
      onRemind = null,
      trailing = null;

  const AuctionCard.row({
    super.key,
    required this.auction,
    this.onTap,
    this.trailing,
  }) : variant = AuctionCardVariant.row,
       onRemind = null;

  final AuctionSummary auction;
  final AuctionCardVariant variant;
  final VoidCallback? onTap;

  /// The "Hatırlat" button on an upcoming card; hidden when null.
  final VoidCallback? onRemind;

  /// Right-hand action of a row.
  final Widget? trailing;

  /// How faded a sold card is.
  static const endedOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    final card = switch (variant) {
      AuctionCardVariant.live => _live(context),
      AuctionCardVariant.upcoming => _upcoming(context, ended: false),
      AuctionCardVariant.ended => Opacity(
        opacity: endedOpacity,
        child: _upcoming(context, ended: true),
      ),
      AuctionCardVariant.row => _row(context),
    };
    return InkWell(borderRadius: AppRadius.cardAll, onTap: onTap, child: card);
  }

  Widget _live(BuildContext context) {
    final endsAt = auction.endsAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuctionPhoto(
          imageUrl: auction.imageUrl,
          label: auction.title,
          aspectRatio: 3 / 4,
          overlay: Stack(
            children: [
              Positioned(
                top: AppSpace.s,
                left: AppSpace.s,
                right: AppSpace.s,
                child: Align(
                  alignment: Alignment.topLeft,
                  // Shrinks rather than overflows with large system text.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: LiveBadge(viewerCount: auction.viewerCount),
                  ),
                ),
              ),
              if (endsAt != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _TimeLeft(endsAt: endsAt),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.s),
        _Seller(username: auction.sellerUsername),
        const SizedBox(height: AppSpace.xs),
        _Title(title: auction.title),
        const SizedBox(height: AppSpace.xs),
        PriceLabel(auction.currentPrice),
      ],
    );
  }

  Widget _upcoming(BuildContext context, {required bool ended}) {
    final onRemind = this.onRemind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuctionPhoto(
          imageUrl: auction.imageUrl,
          label: auction.title,
          aspectRatio: 16 / 9,
          overlay: Padding(
            padding: const EdgeInsets.all(AppSpace.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ended
                        ? const OverlayPill(children: [_PillText('Satıldı')])
                        : _StartsAt(startsAt: auction.startsAt),
                  ),
                ),
                const Spacer(),
                if (!ended && onRemind != null) _RemindButton(onTap: onRemind),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpace.m),
        _Seller(username: auction.sellerUsername),
        const SizedBox(height: AppSpace.xs),
        _Title(title: auction.title),
        const SizedBox(height: AppSpace.xs),
        PriceLabel(auction.currentPrice, prefix: ended ? 'Satıldı' : 'Açılış'),
      ],
    );
  }

  Widget _row(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final trailing = this.trailing;
    return Row(
      children: [
        SizedBox(
          width: AppSize.thumbnail,
          child: AuctionPhoto(
            imageUrl: auction.imageUrl,
            label: auction.title,
            aspectRatio: 1,
            overlay: auction.isLive
                ? const Padding(
                    padding: EdgeInsets.all(AppSpace.xs),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: LiveBadge(),
                      ),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Title(title: auction.title),
              const SizedBox(height: AppSpace.xs),
              Text(
                auction.isLive
                    ? '@${auction.sellerUsername}'
                    : formatStartsAt(auction.startsAt, now: DateTime.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(fontFeatures: AppFonts.tabular),
              ),
              const SizedBox(height: AppSpace.xs),
              Row(
                children: [
                  Flexible(
                    child: PriceLabel(
                      auction.currentPrice,
                      prefix: auction.isLive ? null : 'Açılış',
                    ),
                  ),
                  if (auction.isLive) ...[
                    const SizedBox(width: AppSpace.s),
                    ViewerCount(count: auction.viewerCount),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpace.s), trailing],
      ],
    );
  }
}

/// Avatar and "@username" in the caption style.
class _Seller extends StatelessWidget {
  const _Seller({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialAvatar(username: username, size: AppSize.avatarSmall),
        const SizedBox(width: AppSpace.xs),
        Flexible(
          child: Text(
            '@$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall,
    );
  }
}

/// The time left over a gradient at the foot of a live card's photo: the
/// one place a gradient is used, so white text reads on any picture.
class _TimeLeft extends StatelessWidget {
  const _TimeLeft({required this.endsAt});

  final DateTime endsAt;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.overlay.withValues(alpha: 0), palette.overlay],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s,
          AppSpace.xl,
          AppSpace.s,
          AppSpace.s,
        ),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: AppSize.iconSmall,
              color: palette.onOverlay,
            ),
            const SizedBox(width: AppSpace.xs),
            Countdown(
              endsAt: endsAt,
              style: AppTypeScale.label.copyWith(
                color: palette.onOverlay,
                fontWeight: FontWeight.w800,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Bugün 21:00" on an upcoming card's photo.
class _StartsAt extends StatelessWidget {
  const _StartsAt({required this.startsAt});

  final DateTime startsAt;

  @override
  Widget build(BuildContext context) {
    return OverlayPill(
      children: [
        Icon(
          Icons.schedule,
          size: AppSize.iconSmall,
          color: context.palette.onOverlay,
        ),
        const SizedBox(width: AppSpace.xs),
        _PillText(formatStartsAt(startsAt, now: DateTime.now())),
      ],
    );
  }
}

class _PillText extends StatelessWidget {
  const _PillText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        color: context.palette.onOverlay,
        fontWeight: FontWeight.w700,
        fontFeatures: AppFonts.tabular,
      ),
    );
  }
}

/// The bell on an upcoming card's photo, on the dark overlay.
class _RemindButton extends StatelessWidget {
  const _RemindButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      tooltip: 'Hatırlat',
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: palette.overlay,
        foregroundColor: palette.onOverlay,
      ),
      icon: const Icon(Icons.notifications_none),
    );
  }
}
