import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/routes.dart';
import '../../core/app_failure.dart';
import '../../core/widgets/states.dart';
import '../../data/auction_feed_repository.dart';
import 'feed_providers.dart';
import 'widgets/auction_card.dart';
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
                onRefresh: () => ref.refresh(discoverProvider.future),
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
  const _List({required this.onRefresh, required this.live});

  final Future<void> Function() onRefresh;
  final List<AuctionSummary> live;

  @override
  Widget build(BuildContext context) {
    if (live.isEmpty) {
      return PullToRefresh(
        onRefresh: onRefresh,
        child: const EmptyView(
          icon: Icons.sensors_off_outlined,
          title: 'Şu an canlı yayın yok',
          message: 'Yaklaşan mezatlar Keşfet’te.',
        ),
      );
    }
    return PullToRefresh(
      onRefresh: onRefresh,
      scrollable: true,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpace.edge,
          0,
          AppSpace.edge,
          AppSpace.xl,
        ),
        itemCount: live.length,
        separatorBuilder: (_, _) => const Divider(height: AppSpace.xl),
        itemBuilder: (context, i) => AuctionCard.row(
          auction: live[i],
          onTap: () => context.push(AppRoutes.liveRoom(live[i].id)),
          trailing: Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
