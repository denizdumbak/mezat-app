import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/routes.dart';
import '../../core/app_failure.dart';
import '../../core/widgets/states.dart';
import '../../data/auction_feed_repository.dart';
import '../auth/session.dart';
import 'feed_providers.dart';
import 'widgets/auction_card.dart';
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

    Future<void> reload() => ref.refresh(discoverProvider.future);

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
              child: PullToRefresh(
                onRefresh: reload,
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
            ),
          ],
        ),
        AsyncData(:final value) => PullToRefresh(
          onRefresh: reload,
          scrollable: true,
          child: _DiscoverList(
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
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
              itemBuilder: (context, i) => AuctionCard.upcoming(
                auction: upcoming[i],
                // Reminders need notifications, which come after the MVP.
                onRemind: () => showAppMessage(
                  context,
                  'Hatırlatmalar bildirimlerle birlikte gelecek.',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The live auctions, side by side.
class _LiveStrip extends StatelessWidget {
  const _LiveStrip({required this.live});

  final List<AuctionSummary> live;

  @override
  Widget build(BuildContext context) {
    // No frame: space and the photos set the strip apart.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Şimdi canlı', leading: LiveDot()),
          SizedBox(
            // The card's 3:4 photo plus the text under it.
            height:
                AppSize.liveCardWidth * 4 / 3 +
                MediaQuery.textScalerOf(context).scale(AppSize.liveCardInfo),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
              itemCount: live.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpace.m),
              itemBuilder: (context, i) => SizedBox(
                width: AppSize.liveCardWidth,
                child: AuctionCard.live(
                  auction: live[i],
                  onTap: () => context.push(AppRoutes.liveRoom(live[i].id)),
                ),
              ),
            ),
          ),
        ],
      ),
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
      borderRadius: AppRadius.pillAll,
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
