import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/routes.dart';
import '../../core/app_failure.dart';
import '../../core/time_format.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/states.dart';
import '../../data/auction_feed_repository.dart';
import 'feed_providers.dart';
import 'widgets/screen_header.dart';

/// Yayın aç: create an auction, and go live with one already planned.
class SellScreen extends ConsumerWidget {
  const SellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduled = ref.watch(myScheduledProvider);
    final text = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      child: PullToRefresh(
        onRefresh: () => ref.refresh(myScheduledProvider.future),
        scrollable: true,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: AppSpace.xl),
          children: [
            const ScreenHeader(title: 'Yayın aç'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ürününü ekle; hazır olduğunda yayını başlat.',
                    style: text.bodyMedium!.copyWith(
                      color: AppColors.onStageMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpace.l),
                  PrimaryButton(
                    label: 'Mezat oluştur',
                    onPressed: () => context.push(AppRoutes.createAuction),
                  ),
                ],
              ),
            ),
            const SectionLabel('Planlanmış mezatların'),
            switch (scheduled) {
              AsyncData(:final value) when value.isEmpty => Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
                child: Text(
                  'Henüz planlanmış mezatın yok.',
                  style: text.bodyMedium!.copyWith(
                    color: AppColors.onStageMuted,
                  ),
                ),
              ),
              AsyncData(:final value) => Column(
                children: [
                  for (final auction in value) _ScheduledRow(auction: auction),
                ],
              ),
              AsyncError(:final error) => ErrorView(
                message: failureMessage(error),
                onRetry: () => ref.invalidate(myScheduledProvider),
              ),
              _ => const Padding(
                padding: EdgeInsets.all(AppSpace.xl),
                child: LoadingView(),
              ),
            },
          ],
        ),
      ),
    );
  }
}

class _ScheduledRow extends ConsumerWidget {
  const _ScheduledRow({required this.auction});

  final AuctionSummary auction;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(auctionFeedRepositoryProvider).startAuction(auction.id);
      refreshAuctionLists(ref);
      if (context.mounted) {
        unawaited(context.push(AppRoutes.liveRoom(auction.id)));
      }
    } catch (error) {
      if (context.mounted) {
        showAppMessage(
          context,
          failureMessage(error),
          tone: AppMessageTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.edge,
        0,
        AppSpace.edge,
        AppSpace.m,
      ),
      child: AppPanel(
        child: Row(
          children: [
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
                    '${formatStartsAt(auction.startsAt, now: DateTime.now())}'
                    ' · Açılış ${auction.currentPrice.format()}',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.s),
            TextButton(
              onPressed: () => _start(context, ref),
              child: const Text('Yayını başlat'),
            ),
          ],
        ),
      ),
    );
  }
}
