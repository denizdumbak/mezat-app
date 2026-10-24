import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../../core/app_failure.dart';
import '../../core/auction_failure.dart';
import '../../core/auction_rules.dart';
import '../../core/money.dart';
import '../../core/widgets/bid_feed_row.dart';
import '../../core/widgets/countdown.dart';
import '../../core/widgets/increment_chip.dart';
import '../../core/widgets/price_display.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/sold_stamp.dart';
import '../../core/widgets/states.dart';
import '../../data/auction_feed_repository.dart';
import '../../data/spending_limit_repository.dart';
import '../auctions/feed_providers.dart';
import '../auctions/widgets/auction_visuals.dart';
import '../auth/session.dart';
import 'bid_safety.dart';
import 'bid_sheets.dart';
import 'live_room_controller.dart';

/// The live auction: full-screen video, seller and viewers on top, the bid
/// feed on the left, the bid panel at the bottom.
class LiveRoomScreen extends ConsumerStatefulWidget {
  const LiveRoomScreen({super.key, required this.auctionId});

  final String auctionId;

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

/// How many bids the feed shows.
const _feedLength = 5;

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  int _selectedIncrement = 0;

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(liveRoomProvider(widget.auctionId));

    ref.listen(liveRoomControllerProvider(widget.auctionId), (_, next) {
      final error = next.error;
      // A refusal over the limit opens the raise sheet instead (_send).
      if (error != null &&
          !next.isLoading &&
          error != AuctionFailure.spendingLimitExceeded) {
        showAppMessage(
          context,
          failureMessage(error),
          tone: AppMessageTone.error,
        );
      }
    });

    return Scaffold(
      body: switch (room) {
        AsyncData(:final value) => _buildRoom(value),
        AsyncError(:final error) => SafeArea(
          child: Column(
            children: [
              const Align(alignment: Alignment.centerLeft, child: BackButton()),
              Expanded(
                child: ErrorView(
                  message: failureMessage(error),
                  onRetry: () =>
                      ref.invalidate(liveRoomProvider(widget.auctionId)),
                ),
              ),
            ],
          ),
        ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _buildRoom(LiveRoom room) {
    final userId = ref.watch(authUserIdProvider).value;
    final committed = ref.watch(committedProvider).value ?? Money.zero;
    final config = ref.watch(bidSafetyConfigProvider);
    final limit =
        ref.watch(spendingLimitProvider).value ?? SpendingLimit.defaults;
    final sending = ref
        .watch(liveRoomControllerProvider(room.auctionId))
        .isLoading;

    final increments = room.increments;
    final selected = _selectedIncrement.clamp(0, increments.length - 1);
    final increment = increments[selected];
    final amount = room.currentPrice + increment;
    final leading = room.leadingBid;
    final myLeading = leading != null && leading.bidderId == userId
        ? leading.amount
        : Money.zero;
    final isSeller = room.sellerId == userId;

    final bidCheck = checkBid(
      amount: amount,
      committed: committed,
      myLeadingHere: myLeading,
      limit: limit,
      confirmThreshold: config.confirmThreshold,
    );

    // Why bidding is not possible right now, if it is not.
    final blockedReason = switch (room) {
      _ when room.ended => null,
      _ when !room.connected => 'Bağlantı bekleniyor.',
      _ when isSeller => 'Kendi mezatına teklif veremezsin.',
      // The server refuses the leader's bid (ALREADY_WINNING).
      _ when myLeading.isPositive =>
        'Biri geçerse yeniden teklif verebilirsin.',
      _ => null,
    };
    final canBid = blockedReason == null && !room.ended;
    final scheme = Theme.of(context).colorScheme;
    final (note, noteColor) = switch (bidCheck) {
      _ when blockedReason != null => (
        blockedReason,
        switch (room) {
          // Waiting for the connection, or for a rival: not errors.
          _ when !room.connected => context.palette.warning,
          _ when myLeading.isPositive => scheme.onSurfaceVariant,
          _ => scheme.error,
        },
      ),
      BidOverLimit(:final overage) when canBid => (
        overLimitNote(limit, overage),
        context.palette.warning,
      ),
      _ => (null, null),
    };

    Future<void> placeBid() async {
      switch (bidCheck) {
        case BidOverLimit(:final overage):
          await _raiseLimitAndBid(room, amount, limit, overage);
          return;
        case BidAllowed(needsConfirmation: true, :final committedAfter):
          final ok = await confirmHighBid(
            context,
            amount: amount,
            committedAfter: committedAfter,
          );
          if (!ok || !mounted) return;
        case BidAllowed():
      }
      await _send(room, amount);
    }

    // Once it is over the stamp takes the stage; the feed would only
    // show through behind it.
    final feed = room.ended
        ? const <Bid>[]
        : room.bids.take(_feedLength).toList().reversed;

    return Stack(
      fit: StackFit.expand,
      children: [
        const _VideoPlaceholder(),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(room: room),
              if (!room.connected)
                const Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpace.edge,
                    AppSpace.s,
                    AppSpace.edge,
                    0,
                  ),
                  child: ConnectionBanner(),
                ),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.edge),
                    // On short screens the oldest rows are clipped at the top
                    // instead of overflowing.
                    child: SingleChildScrollView(
                      reverse: true,
                      physics: const NeverScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppSize.bidFeedWidth,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final bid in feed)
                              Padding(
                                key: ValueKey(bid.id),
                                padding: const EdgeInsets.only(
                                  top: AppSpace.xs,
                                ),
                                child: BidFeedRow(
                                  username: bid.username,
                                  amount: bid.amount,
                                  isMine: bid.bidderId == userId,
                                  isLeading: bid.id == leading?.id,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _BidPanel(
                room: room,
                userId: userId,
                increments: increments,
                selected: selected,
                onSelect: canBid
                    ? (i) => setState(() => _selectedIncrement = i)
                    : null,
                bidLabel: '+${increment.format()} teklif ver',
                onBid: canBid ? placeBid : null,
                sending: sending,
                note: note,
                noteColor: noteColor,
              ),
            ],
          ),
        ),
        if (room.sold case final sold?)
          SoldStamp(
            winnerUsername: sold.winnerUsername,
            amount: sold.amount,
            isMe: sold.winnerId == userId,
            action: OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Mezattan çık'),
            ),
          )
        else if (room.ended)
          ColoredBox(
            color: context.palette.scrimStrong,
            child: EmptyView(
              icon: Icons.timer_off_outlined,
              title: 'Süre doldu',
              message: 'Bu mezata teklif gelmedi.',
              action: OutlinedButton(
                onPressed: () => context.pop(),
                child: const Text('Mezattan çık'),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _send(LiveRoom room, Money amount) async {
    final provider = liveRoomControllerProvider(room.auctionId);
    await ref.read(provider.notifier).placeBid(amount);
    if (!mounted ||
        ref.read(provider).error != AuctionFailure.spendingLimitExceeded) {
      return;
    }
    // The server counted more than this screen knew (say, an auction won on
    // another device). Ask again with its total.
    final committed = await ref.refresh(committedProvider.future);
    final limit =
        ref.read(spendingLimitProvider).value ?? SpendingLimit.defaults;
    final overage = committed + amount - limit.amount;
    if (!mounted) return;
    if (!overage.isPositive) {
      showAppMessage(
        context,
        AuctionFailure.spendingLimitExceeded.message,
        tone: AppMessageTone.error,
      );
      return;
    }
    await _raiseLimitAndBid(room, amount, limit, overage);
  }

  /// "Limit aşıldı" → "Limiti artır" → "Emin misin?" → raises the limit by
  /// exactly [overage] and sends the bid. The last sheet names the amount,
  /// so there is no separate high-bid confirmation.
  Future<void> _raiseLimitAndBid(
    LiveRoom room,
    Money amount,
    SpendingLimit limit,
    Money overage,
  ) async {
    final raise = await offerLimitRaise(
      context,
      limit: limit,
      overage: overage,
    );
    if (!raise || !mounted) return;
    final raised = limit.amount + overage;
    final sure = await confirmLimitRaise(
      context,
      from: limit.amount,
      to: raised,
      amount: amount,
    );
    if (!sure || !mounted) return;
    try {
      await ref
          .read(spendingLimitProvider.notifier)
          .change(limit.copyWith(amount: raised));
    } catch (error) {
      if (mounted) {
        showAppMessage(
          context,
          failureMessage(error),
          tone: AppMessageTone.error,
        );
      }
      return;
    }
    if (!mounted) return;
    await _send(room, amount);
  }
}

/// Stands in for the LiveKit video until M4.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      // Above the bid feed and panel, not behind them.
      child: Align(
        alignment: const Alignment(0, -0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: AppSize.touch,
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              'Yayın görüntüsü',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.room});

  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s),
      child: Row(
        children: [
          const BackButton(),
          InitialAvatar(username: room.sellerUsername),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '@${room.sellerUsername}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpace.xs),
                const LiveBadge(),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s),
          ViewerCount(count: room.viewerCount),
          const SizedBox(width: AppSpace.s),
        ],
      ),
    );
  }
}

class _BidPanel extends StatelessWidget {
  const _BidPanel({
    required this.room,
    required this.userId,
    required this.increments,
    required this.selected,
    required this.onSelect,
    required this.bidLabel,
    required this.onBid,
    required this.sending,
    required this.note,
    required this.noteColor,
  });

  final LiveRoom room;
  final String? userId;
  final List<Money> increments;
  final int selected;
  final ValueChanged<int>? onSelect;
  final String bidLabel;
  final VoidCallback? onBid;
  final bool sending;

  /// Why the button is off, or a warning about the bid it would send.
  final String? note;
  final Color? noteColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final leading = room.leadingBid;
    final (leaderText, leaderColor) = switch (leading) {
      null => ('İlk teklifi sen ver', scheme.onSurfaceVariant),
      _ when leading.bidderId == userId => ('Öndesin', palette.success),
      _ => ('Önde: @${leading.username}', scheme.onSurfaceVariant),
    };
    final note = this.note;

    // The bottom panel: blurred over the video, and the one place with a
    // shadow.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.sheetTop,
        boxShadow: [BoxShadow(color: palette.overlay, blurRadius: AppSpace.xl)],
      ),
      child: BlurredPanel(
        borderRadius: AppRadius.sheetTop,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.edge,
              AppSpace.l,
              AppSpace.edge,
              AppSpace.l,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: AppSpace.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: PriceDisplay(amount: room.currentPrice),
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Countdown(endsAt: room.endsAt),
                  ],
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  leaderText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(color: leaderColor),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Artış ${room.minIncrement.format()} · Son '
                  '${antiSnipingWindow.inSeconds} sn’de teklif '
                  '+${antiSnipingExtension.inSeconds} sn uzatır',
                  style: text.bodySmall,
                ),
                const SizedBox(height: AppSpace.m),
                Row(
                  children: [
                    for (final (i, increment) in increments.indexed) ...[
                      if (i > 0) const SizedBox(width: AppSpace.s),
                      Expanded(
                        child: IncrementChip(
                          increment: increment,
                          selected: i == selected,
                          onSelected: onSelect == null
                              ? null
                              : () => onSelect!(i),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.m),
                PrimaryButton.bid(
                  label: bidLabel,
                  onPressed: onBid,
                  busy: sending,
                ),
                if (note != null) ...[
                  const SizedBox(height: AppSpace.s),
                  Text(
                    note,
                    key: const Key('liveRoom.note'),
                    textAlign: TextAlign.center,
                    style: text.bodySmall!.copyWith(color: noteColor),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
