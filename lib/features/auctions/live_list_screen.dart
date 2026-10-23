import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/routes.dart';
import '../../core/app_failure.dart';
import '../../core/widgets/states.dart';
import '../../data/auction_feed_repository.dart';
import 'feed_providers.dart';
import 'widgets/auction_visuals.dart';
import 'widgets/screen_header.dart';

/// Canlı: every auction streaming right now.
class LiveListScreen extends ConsumerWidget {
  const LiveListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auctions = ref.watch(discoverProvider);
    const header = ScreenHeader(title: 'Canlı');

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          header,
          Expanded(
            child: switch (auctions) {
              AsyncData(:final value) => _List(
                live: [
                  for (final a in value)
                    if (a.isLive) a,
                ],
              ),
              AsyncError(:final error) => ErrorView(
                message: failureMessage(error),
                onRetry: () => ref.invalidate(discoverProvider),
              ),
              _ => const LoadingView(),
            },
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.live});

  final List<AuctionSummary> live;

  @override
  Widget build(BuildContext context) {
    if (live.isEmpty) {
      return const EmptyView(
        icon: Icons.sensors_off_outlined,
        title: 'Şu an canlı yayın yok',
        message: 'Yaklaşan mezatlar Keşfet’te.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.edge,
        0,
        AppSpace.edge,
        AppSpace.xl,
      ),
      itemCount: live.length,
      separatorBuilder: (_, _) => const Divider(height: AppSpace.xl),
      itemBuilder: (context, i) => _LiveRow(auction: live[i]),
    );
  }
}

class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.auction});

  final AuctionSummary auction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: AppRadius.smallAll,
      onTap: () => context.push(AppRoutes.liveRoom(auction.id)),
      child: Row(
        children: [
          SizedBox(
            width: AppSize.thumbnail,
            child: AuctionPhoto(
              imageUrl: auction.imageUrl,
              aspectRatio: 1,
              borderRadius: AppRadius.smallAll,
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  auction.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
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
                    Flexible(
                      child: Text(
                        auction.currentPrice.format(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.price,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s),
                    ViewerCount(count: auction.viewerCount),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.onStageMuted),
        ],
      ),
    );
  }
}
