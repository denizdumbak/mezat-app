import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/app_failure.dart';
import '../../core/widgets/form_layout.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/states.dart';
import '../../data/auction_feed_repository.dart';
import '../auth/session.dart';
import 'auction_categories.dart';
import 'feed_providers.dart';
import 'widgets/auction_card.dart';
import 'widgets/auction_visuals.dart';

/// Keşfet, home: the logo and your avatar, a search field and category
/// chips (both filter what is loaded, on the phone), then "Şimdi canlı" as a
/// two-column grid, busiest first, and "Yaklaşan" as a row of smaller cards.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  /// Live cards shown before "Tümü".
  static const liveShown = 6;

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  final _upcomingKey = GlobalKey();
  AuctionCategory? _category;
  var _allLive = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(AuctionSummary auction) {
    final query = turkishLower(_search.text.trim());
    final inQuery =
        query.isEmpty ||
        turkishLower(auction.title).contains(query) ||
        turkishLower(auction.sellerUsername).contains(query);
    final category = _category;
    return inQuery && (category == null || category.matches(auction.title));
  }

  void _clearFilters() => setState(() {
    _search.clear();
    _category = null;
  });

  @override
  Widget build(BuildContext context) {
    final auctions = ref.watch(discoverProvider);
    final username = ref.watch(currentProfileProvider).value?.username;

    final controls = <Widget>[
      SliverToBoxAdapter(child: _TopBar(username: username)),
      SliverToBoxAdapter(
        child: _SearchField(
          controller: _search,
          onChanged: () => setState(() {}),
        ),
      ),
      SliverToBoxAdapter(
        child: _CategoryChips(
          selected: _category,
          onSelected: (category) => setState(() => _category = category),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xxl)),
    ];

    return SafeArea(
      bottom: false,
      child: switch (auctions) {
        AsyncData(:final value) => PullToRefresh(
          onRefresh: () => ref.refresh(discoverProvider.future),
          scrollable: true,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [...controls, ..._sections(value)],
          ),
        ),
        AsyncError(:final error) => CustomScrollView(
          slivers: [
            ...controls,
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: failureMessage(error),
                onRetry: () => ref.invalidate(discoverProvider),
              ),
            ),
          ],
        ),
        _ => CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [...controls, const _DiscoverSkeleton()],
        ),
      },
    );
  }

  List<Widget> _sections(List<AuctionSummary> all) {
    if (all.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.storefront_outlined,
            title: 'Şu an mezat yok',
            message: 'Yeni mezatlar planlandığında burada görünecek.',
            action: OutlinedButton(
              onPressed: () => context.go(AppRoutes.sell),
              child: const Text('Sat'),
            ),
          ),
        ),
      ];
    }

    final matching = all.where(_matches).toList();
    if (matching.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.search_off,
            title: 'Sonuç yok',
            message: 'Başka bir kelime ya da kategori dene.',
            action: OutlinedButton(
              onPressed: _clearFilters,
              child: const Text('Filtreyi temizle'),
            ),
          ),
        ),
      ];
    }

    final live = [
      for (final a in matching)
        if (a.isLive) a,
    ]..sort((a, b) => b.viewerCount.compareTo(a.viewerCount));
    final upcoming = [
      for (final a in matching)
        if (!a.isLive && !a.isEnded) a,
    ];
    final shownLive = _allLive
        ? live
        : live.take(DiscoverScreen.liveShown).toList();

    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          title: 'Şimdi canlı',
          leading: const LiveDot(),
          trailing: live.length > DiscoverScreen.liveShown
              ? TextButton(
                  onPressed: () => setState(() => _allLive = !_allLive),
                  child: Text(_allLive ? 'Daha az' : 'Tümü'),
                )
              : null,
        ),
      ),
      if (live.isEmpty)
        SliverToBoxAdapter(
          child: _NoneLive(
            onShowUpcoming: upcoming.isEmpty
                ? null
                : () => Scrollable.ensureVisible(
                    _upcomingKey.currentContext!,
                    duration: AppDurations.entry,
                    curve: AppCurves.enter,
                  ),
          ),
        )
      else
        _LiveGrid(
          live: shownLive,
          onOpen: (a) => context.push(AppRoutes.liveRoom(a.id)),
        ),
      if (upcoming.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xxl)),
        SliverToBoxAdapter(
          child: _SectionHeader(key: _upcomingKey, title: 'Yaklaşan'),
        ),
        SliverToBoxAdapter(
          child: _UpcomingRow(
            upcoming: upcoming,
            // Reminders need notifications, which come after the MVP.
            onRemind: () => showAppMessage(
              context,
              'Hatırlatmalar bildirimlerle birlikte gelecek.',
            ),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: AppSpace.xxl)),
    ];
  }
}

/// The small logo on the left, your avatar (to Profil) on the right.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.username});

  final String? username;

  @override
  Widget build(BuildContext context) {
    final username = this.username;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.edge,
        AppSpace.s,
        AppSpace.s,
        AppSpace.s,
      ),
      child: Row(
        children: [
          const Wordmark(),
          const Spacer(),
          if (username != null)
            Semantics(
              button: true,
              label: 'Profil, @$username',
              excludeSemantics: true,
              child: InkResponse(
                key: const Key('discover.avatar'),
                radius: AppSize.touch / 2,
                onTap: () => context.go(AppRoutes.profile),
                child: SizedBox.square(
                  dimension: AppSize.touch,
                  child: Center(child: InitialAvatar(username: username)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One line, a pill on the secondary surface.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    const none = OutlineInputBorder(
      borderRadius: AppRadius.pillAll,
      borderSide: BorderSide.none,
    );
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
      child: TextField(
        key: const Key('discover.search'),
        controller: controller,
        onChanged: (_) => onChanged(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Ürün ya da satıcı ara',
          prefixIcon: Icon(Icons.search, color: muted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Temizle',
                  icon: Icon(Icons.close, color: muted),
                  onPressed: () {
                    controller.clear();
                    onChanged();
                  },
                ),
          fillColor: context.palette.panel,
          border: none,
          enabledBorder: none,
          focusedBorder: none,
        ),
      ),
    );
  }
}

/// Tümü and the categories, scrolling sideways.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onSelected});

  final AuctionCategory? selected;
  final ValueChanged<AuctionCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <AuctionCategory?>[null, ...AuctionCategory.values];
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.m),
      child: SizedBox(
        height: AppSize.touch,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
          itemCount: options.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s),
          itemBuilder: (context, i) => _Chip(
            key: Key('category.${options[i]?.name ?? 'all'}'),
            label: options[i]?.label ?? 'Tümü',
            selected: options[i] == selected,
            onTap: () => onSelected(options[i]),
          ),
        ),
      ),
    );
  }
}

/// Selected: filled in the text colour. Never the accent, which is for
/// actions.
class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Center(
        child: Material(
          color: selected ? scheme.onSurface : context.palette.panel,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.l,
                vertical: AppSpace.s,
              ),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: selected ? scheme.surface : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A section title in the headline style, with an optional action.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final leading = this.leading;
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.edge,
        0,
        AppSpace.s,
        AppSpace.s,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSize.touch),
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: AppSpace.s),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Two live cards per row; the height fits the 3:4 photo and the text.
class _LiveGrid extends StatelessWidget {
  const _LiveGrid({required this.live, required this.onOpen});

  final List<AuctionSummary> live;
  final ValueChanged<AuctionSummary> onOpen;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) => SliverGrid.builder(
          gridDelegate: _twoColumns(context, constraints.crossAxisExtent),
          itemCount: live.length,
          itemBuilder: (context, i) => AuctionCard.live(
            key: ValueKey(live[i].id),
            auction: live[i],
            onTap: () => onOpen(live[i]),
          ),
        ),
      ),
    );
  }
}

SliverGridDelegate _twoColumns(BuildContext context, double width) {
  final cardWidth = (width - AppSpace.m) / 2;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    crossAxisSpacing: AppSpace.m,
    mainAxisSpacing: AppSpace.m,
    mainAxisExtent:
        cardWidth * 4 / 3 +
        MediaQuery.textScalerOf(context).scale(AppSize.liveCardInfo),
  );
}

/// Upcoming auctions side by side, smaller than the live ones.
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.upcoming, required this.onRemind});

  final List<AuctionSummary> upcoming;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height:
          AppSize.upcomingCardWidth * 9 / 16 +
          MediaQuery.textScalerOf(context).scale(AppSize.upcomingCardInfo),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
        itemCount: upcoming.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpace.m),
        itemBuilder: (context, i) => SizedBox(
          key: ValueKey(upcoming[i].id),
          width: AppSize.upcomingCardWidth,
          child: AuctionCard.upcoming(auction: upcoming[i], onRemind: onRemind),
        ),
      ),
    );
  }
}

/// Nothing live right now (or nothing live matches the filter).
class _NoneLive extends StatelessWidget {
  const _NoneLive({required this.onShowUpcoming});

  /// Scrolls to Yaklaşan; null when there is nothing coming up either.
  final VoidCallback? onShowUpcoming;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final onShowUpcoming = this.onShowUpcoming;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          children: [
            Icon(
              Icons.sensors_off_outlined,
              size: AppSize.touch,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpace.m),
            Text(
              'Şu an canlı mezat yok',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (onShowUpcoming != null) ...[
              const SizedBox(height: AppSpace.l),
              OutlinedButton(
                onPressed: onShowUpcoming,
                child: const Text('Yaklaşanlara bak'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The loading state: the shape of the page, with light sweeping across.
class _DiscoverSkeleton extends StatelessWidget {
  const _DiscoverSkeleton();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Shimmer(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.edge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FractionallySizedBox(
                widthFactor: _SkeletonCard.titleWidth,
                child: SkeletonBox(height: AppSpace.xl),
              ),
              const SizedBox(height: AppSpace.l),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = (constraints.maxWidth - AppSpace.m) / 2;
                  return Wrap(
                    spacing: AppSpace.m,
                    runSpacing: AppSpace.m,
                    children: [
                      for (var i = 0; i < 4; i++)
                        SizedBox(
                          width: cardWidth,
                          child: const _SkeletonCard(),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A live card's shape: photo, seller, title, price.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  /// Widths relative to the space they sit in, like the text they stand for.
  static const titleWidth = 0.4;
  static const sellerWidth = 0.6;
  static const priceWidth = 0.45;

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 3 / 4, child: SkeletonBox()),
        SizedBox(height: AppSpace.s),
        FractionallySizedBox(
          widthFactor: sellerWidth,
          child: SkeletonBox(height: AppSpace.m),
        ),
        SizedBox(height: AppSpace.s),
        SkeletonBox(height: AppSpace.l),
        SizedBox(height: AppSpace.xs),
        FractionallySizedBox(
          widthFactor: priceWidth,
          child: SkeletonBox(height: AppSpace.l),
        ),
      ],
    );
  }
}
