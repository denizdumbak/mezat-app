import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/auction_rules.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/widgets/increment_chip.dart';

import '../helpers/fakes.dart';
import '../helpers/sample_data.dart';
import '../helpers/screens.dart';

/// States that come with real auctions before M3: no bids yet, no viewer
/// counts, lists that refresh by pulling or after a change.
void main() {
  testWidgets(
    'bidding not open yet: the room says so and nothing is tappable',
    (tester) async {
      useSmallPhone(tester);
      final feed = FakeAuctionFeedRepository()
        ..discover = [liveAuction()]
        ..rooms['zenit'] = liveRoom(
          bids: const [],
        ).copyWith(biddingOpen: false);
      await pumpSignedIn(tester, feed: feed);
      await tester.tap(find.text('Zenit-E analog fotoğraf makinesi (1978)'));
      await tester.pumpAndSettle();

      expect(find.text(AuctionFailure.biddingNotOpen.message), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      for (final chip in tester.widgetList<IncrementChip>(
        find.byType(IncrementChip),
      )) {
        expect(chip.onSelected, isNull);
      }
    },
  );

  testWidgets('no viewer count yet: the eye icon is not shown', (tester) async {
    useSmallPhone(tester);
    await pumpSignedIn(
      tester,
      feed: FakeAuctionFeedRepository()..discover = [liveAuction(viewers: 0)],
    );

    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('pulling Keşfet down loads it again', (tester) async {
    useSmallPhone(tester);
    final feed = FakeAuctionFeedRepository()..discover = [upcomingAuction()];
    await pumpSignedIn(tester, feed: feed);
    final before = feed.discoverCalls;

    feed.discover = [upcomingAuction(), liveAuction()];
    await tester.fling(find.text('Yaklaşan'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(feed.discoverCalls, greaterThan(before));
    expect(find.text('Şimdi canlı'), findsOneWidget);
  });

  testWidgets('an empty Keşfet can be pulled too', (tester) async {
    useSmallPhone(tester);
    final feed = FakeAuctionFeedRepository();
    await pumpSignedIn(tester, feed: feed);

    feed.discover = [upcomingAuction()];
    await tester.fling(
      find.text('Şu an mezat yok'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Yaklaşan'), findsOneWidget);
  });

  testWidgets('after creating an auction, Yayın aç lists it', (tester) async {
    useSmallPhone(tester);
    final feed = FakeAuctionFeedRepository();
    await pumpSignedIn(tester, feed: feed);
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    expect(find.text('Henüz planlanmış mezatın yok.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Mezat oluştur'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('createAuction.title')),
      'Pirinç cezve',
    );
    await tester.enterText(
      find.byKey(const Key('createAuction.startPrice')),
      '400',
    );
    await tester.enterText(
      find.byKey(const Key('createAuction.minIncrement')),
      '10',
    );
    // The server now has it; the list must fetch again to show it.
    feed.myScheduled = [upcomingAuction(id: 'new', title: 'Pirinç cezve')];
    await tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Mezatı oluştur'),
    );

    expect(find.text('Pirinç cezve'), findsOneWidget);
    expect(find.text('Henüz planlanmış mezatın yok.'), findsNothing);
  });

  test('increment chips never go below the minimum step', () {
    expect(incrementsFor(const Money.kurus(1000)), defaultIncrements);
    expect(incrementsFor(const Money.kurus(500)), defaultIncrements);
    expect(incrementsFor(const Money.kurus(2500)), const [
      Money.kurus(2500),
      Money.kurus(12500),
      Money.kurus(25000),
    ]);
  });
}
