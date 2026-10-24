import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
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
      if (error != null && !next.isLoading) {
        showAppMessage(
          context,
          failureMessage(error),
          tone: AppMessageTone.error,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.stage,
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

    BidCheck check(Money amount) => checkBid(
      amount: amount,
      committed: committed,
      myLeadingHere: myLeading,
      limit: limit,
      confirmThreshold: config.confirmThreshold,
    );
    final bidCheck = check(amount);

    // Why bidding is not possible right now, if it is not.
    final blockedReason = switch (bidCheck) {
      _ when room.ended => null,
      _ when !room.connected => 'Bağlantı bekleniyor.',
      _ when isSeller => 'Kendi mezatına teklif veremezsin.',
      _ when !room.biddingOpen => AuctionFailure.biddingNotOpen.message,
      BidBlocked(:final reason) => reason,
      BidAllowed() => null,
    };
    final canBid = blockedReason == null && !room.ended;

    Future<void> placeBid() async {
      if (bidCheck case BidAllowed(
        needsConfirmation: true,
        :final committedAfter,
      )) {
        final ok = await confirmHighBid(
          context,
          amount: amount,
          committedAfter: committedAfter,
        );
        if (!ok || !mounted) return;
      }
      await ref
          .read(liveRoomControllerProvider(room.auctionId).notifier)
          .placeBid(amount);
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
                blockedReason: blockedReason,
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
            color: AppColors.scrimStrong,
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
}

/// Stands in for the LiveKit video until M4.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.stage,
      // Above the bid feed and panel, not behind them.
      child: Align(
        alignment: const Alignment(0, -0.4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_outlined,
              color: AppColors.onStageMuted,
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
    required this.blockedReason,
  });

  final LiveRoom room;
  final String? userId;
  final List<Money> increments;
  final int selected;
  final ValueChanged<int>? onSelect;
  final String bidLabel;
  final VoidCallback? onBid;
  final bool sending;
  final String? blockedReason;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final leading = room.leadingBid;
    final (leaderText, leaderColor) = switch (leading) {
      null => ('İlk teklifi sen ver', AppColors.onStageMuted),
      _ when leading.bidderId == userId => ('Öndesin', AppColors.success),
      _ => ('Önde: @${leading.username}', AppColors.onStageMuted),
    };
    final blockedReason = this.blockedReason;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stageRaised,
        borderRadius: AppRadius.largeTop,
        border: Border(
          top: BorderSide(color: AppColors.line, width: AppSize.line),
        ),
      ),
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
              if (blockedReason != null) ...[
                const SizedBox(height: AppSpace.s),
                Text(
                  blockedReason,
                  key: const Key('liveRoom.blockedReason'),
                  textAlign: TextAlign.center,
                  style: text.bodySmall!.copyWith(color: AppColors.urgent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
