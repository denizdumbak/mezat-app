import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/routes.dart';
import '../../core/app_failure.dart';
import '../../core/time_format.dart';
import '../../core/widgets/states.dart';
import '../../data/auction_feed_repository.dart';
import '../auth/session.dart';
import 'feed_providers.dart';
import 'widgets/auction_visuals.dart';
import 'widgets/screen_header.dart';

/// Keşfet: the "live now" strip, then upcoming auctions with a big photo,
/// the opening price and when they start.
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctions = ref.watch(discoverProvider);
    final username = ref.watch(currentProfileProvider).value?.username;

    final header = ScreenHeader(
      title: 'Keşfet',
      trailing: username == null
          ? null
          : _ProfileChip(
              username: username,
              onTap: () => context.go(AppRoutes.profile),
            ),
    );

    return SafeArea(
      bottom: false,
      child: switch (auctions) {
        AsyncData(:final value) when value.isEmpty => Column(
          children: [
            header,
            Expanded(
              child: EmptyView(
                icon: Icons.storefront_outlined,
                title: 'Şu an mezat yok',
                message: 'Yeni mezatlar planlandığında burada görünecek.',
                action: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.sell),
                  child: const Text('Yayın aç'),
                ),
              ),
            ),
          ],
        ),
        AsyncData(:final value) => _DiscoverList(
          header: header,
          live: [
            for (final a in value)
              if (a.isLive) a,
          ],
          upcoming: [
            for (final a in value)
              if (!a.isLive) a,
          ],
        ),
        AsyncError(:final error) => Column(
          children: [
            header,
            Expanded(
              child: ErrorView(
                message: failureMessage(error),
                onRetry: () => ref.invalidate(discoverProvider),
              ),
            ),
          ],
        ),
        _ => Column(
          children: [
            header,
            const Expanded(child: LoadingView()),
          ],
        ),
      },
    );
  }
}

class _DiscoverList extends StatelessWidget {
  const _DiscoverList({
    required this.header,
    required this.live,
    required this.upcoming,
  });

  final Widget header;
  final List<AuctionSummary> live;
  final List<AuctionSummary> upcoming;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: header),
        if (live.isNotEmpty) SliverToBoxAdapter(child: _LiveStrip(live: live)),
        if (upcoming.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SectionLabel('Yaklaşan')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.edge,
              0,
              AppSpace.edge,
              AppSpace.xl,
            ),
            sliver: SliverList.separated(
              itemCount: upcoming.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpace.xl),
              itemBuilder: (context, i) =>
                  _UpcomingItem(auction: upcoming[i], now: now),
            ),
          ),
        ],
      ],
    );
  }
}

/// The live auctions, set apart by lines above and below.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.live});

  final List<AuctionSummary> live;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stage,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.line, width: AppSize.line),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Şimdi canlı', leading: LiveDot()),
            SizedBox(
              height:
                  AppSize.liveCardWidth * 5 / 4 +
                  MediaQuery.textScalerOf(context).scale(AppSize.liveCardInfo),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
                itemCount: live.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.m),
                itemBuilder: (context, i) => _LiveCard(auction: live[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.auction});

  final AuctionSummary auction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      width: AppSize.liveCardWidth,
      child: InkWell(
        borderRadius: AppRadius.largeAll,
        onTap: () => context.push(AppRoutes.liveRoom(auction.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuctionPhoto(
              imageUrl: auction.imageUrl,
              aspectRatio: 4 / 5,
              overlay: Padding(
                padding: const EdgeInsets.all(AppSpace.s),
                // Both pills shrink rather than overflow on narrow cards or
                // with large system text.
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: LiveBadge(),
                      ),
                    ),
                    const SizedBox(width: AppSpace.xs),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ViewerCount(count: auction.viewerCount),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              auction.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall,
            ),
            const SizedBox(height: AppSpace.xs),
            Text(auction.currentPrice.format(), style: AppTextStyles.price),
          ],
        ),
      ),
    );
  }
}

class _UpcomingItem extends StatelessWidget {
  const _UpcomingItem({required this.auction, required this.now});

  final AuctionSummary auction;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuctionPhoto(imageUrl: auction.imageUrl, aspectRatio: 16 / 9),
        const SizedBox(height: AppSpace.m),
        Text(
          auction.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium,
        ),
        const SizedBox(height: AppSpace.xs),
        Text(
          '@${auction.sellerUsername}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpace.s),
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Açılış ', style: text.bodySmall),
                    TextSpan(
                      text: auction.currentPrice.format(),
                      style: AppTextStyles.price,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpace.m),
            const Icon(
              Icons.schedule,
              size: AppSize.iconSmall,
              color: AppColors.onStageMuted,
            ),
            const SizedBox(width: AppSpace.xs),
            Text(
              formatStartsAt(auction.startsAt, now: now),
              style: text.labelMedium!.copyWith(
                color: AppColors.onStage,
                fontFeatures: AppFonts.tabular,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  const _ProfileChip({required this.username, required this.onTap});

  final String username;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.smallAll,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.touch),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: AppColors.onStageMuted,
                ),
              ),
            ),
            const SizedBox(width: AppSpace.s),
            InitialAvatar(username: username),
          ],
        ),
      ),
    );
  }
}
