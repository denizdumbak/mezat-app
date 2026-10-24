import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';
import 'package:mezat_app/features/auctions/discover_screen.dart';
import 'package:mezat_app/features/live_room/live_room_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/sample_data.dart';
import '../helpers/screens.dart';

const _longTitle =
    'Çok uzun başlıklı bir ürün: el yapımı, gümüş kaplama, antika '
    'İstanbul işi kahve takımı ve tepsisi';

Future<void> _openTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('tab.$index')));
  await tester.pumpAndSettle();
}

FakeAuctionFeedRepository _edgeCaseFeed() => FakeAuctionFeedRepository()
  ..discover = [
    liveAuction(
      title: _longTitle,
      seller: longUsername,
      price: sixDigits,
      viewers: 12500,
    ),
    upcomingAuction(title: _longTitle, seller: longUsername, price: sixDigits),
  ]
  ..myScheduled = [
    upcomingAuction(id: 'mine', title: _longTitle, price: sixDigits),
  ];

void main() {
  group('Keşfet', () {
    testWidgets('long names, long titles and 6-digit prices fit', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: _edgeCaseFeed(), username: longUsername);

      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(find.text('@$longUsername'), findsWidgets);
      expect(find.text('₺999.999'), findsWidgets);
      expect(find.text('12 B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('live and upcoming are separate sections', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()
          ..discover = [liveAuction(), upcomingAuction()],
      );

      expect(find.text('Şimdi canlı'), findsOneWidget);
      expect(find.text('Yaklaşan'), findsOneWidget);
      expect(find.textContaining('Bugün'), findsOneWidget);
    });

    testWidgets('a live card opens the live room', (tester) async {
      useSmallPhone(tester);
      final feed = FakeAuctionFeedRepository()
        ..discover = [liveAuction()]
        ..rooms['zenit'] = liveRoom();
      await pumpSignedIn(tester, feed: feed);

      await tester.tap(find.text('Zenit-E analog fotoğraf makinesi (1978)'));
      await tester.pumpAndSettle();

      expect(find.byType(LiveRoomScreen), findsOneWidget);
    });

    testWidgets('empty: says so and offers to start one', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: FakeAuctionFeedRepository());

      expect(find.text('Şu an mezat yok'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Yayın aç'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Mezat oluştur'),
        findsOneWidget,
      );
    });

    testWidgets('connection lost: the reason and a working retry', (
      tester,
    ) async {
      useSmallPhone(tester);
      final feed = FakeAuctionFeedRepository()
        ..discover = [liveAuction()]
        ..discoverError = AuctionFailure.network;
      await pumpSignedIn(tester, feed: feed);

      expect(find.text(AuctionFailure.network.message), findsOneWidget);

      feed.discoverError = null;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(find.text('Şimdi canlı'), findsOneWidget);
    });
  });

  group('Canlı', () {
    testWidgets('lists live auctions only; edge cases fit', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: _edgeCaseFeed());
      await _openTab(tester, 1);

      // One live auction; the upcoming one is not listed here.
      expect(find.text(_longTitle), findsOneWidget);
      expect(find.text('₺999.999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()..discover = [upcomingAuction()],
      );
      await _openTab(tester, 1);

      expect(find.text('Şu an canlı yayın yok'), findsOneWidget);
    });

    testWidgets('connection lost', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()
          ..discoverError = AuctionFailure.network,
      );
      await _openTab(tester, 1);

      expect(find.text(AuctionFailure.network.message), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
    });
  });

  group('Yayın aç', () {
    testWidgets('one primary action; planned auctions listed', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: _edgeCaseFeed());
      await _openTab(tester, 2);

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text(_longTitle), findsOneWidget);
      expect(find.textContaining('₺999.999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('starting a planned auction opens its live room', (
      tester,
    ) async {
      useSmallPhone(tester);
      final feed = _edgeCaseFeed()..rooms['mine'] = liveRoom(id: 'mine');
      await pumpSignedIn(tester, feed: feed);
      await _openTab(tester, 2);

      await tester.tap(find.text('Yayını başlat'));
      await tester.pumpAndSettle();

      expect(feed.started, ['mine']);
      expect(find.byType(LiveRoomScreen), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: FakeAuctionFeedRepository());
      await _openTab(tester, 2);

      expect(find.text('Henüz planlanmış mezatın yok.'), findsOneWidget);
    });
  });

  group('Profil', () {
    testWidgets('long username and a 6-digit total fit', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()..committed = sixDigits,
        username: longUsername,
      );
      await _openTab(tester, 3);

      expect(find.text('@$longUsername'), findsWidgets);
      expect(find.text('Son 1 günde · şu an ₺999.999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the limit starts at ₺2.000 in 1 day and can be changed', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: FakeAuctionFeedRepository());
      await _openTab(tester, 3);

      final limit = find.byKey(const Key('profile.limit'));
      expect(tester.widget<Text>(limit).data, '₺2.000');

      await tapVisible(tester, find.text('Limiti değiştir'));
      await tester.enterText(find.byKey(const Key('profile.limitField')), '');
      await tapVisible(tester, find.text('Kaydet'));
      expect(find.text('Bir tutar gir.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('profile.limitField')),
        '5.000',
      );
      await tapVisible(tester, find.text('Kaydet'));

      expect(tester.widget<Text>(limit).data, '₺5.000');
      expect(
        find.text('Limitin son 1 günde en fazla ₺5.000 oldu.'),
        findsOneWidget,
      );
    });

    testWidgets('a preset period is chosen in the sheet', (tester) async {
      useSmallPhone(tester);
      final store = InMemorySpendingLimitRepository();
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository(),
        spendingLimit: store,
      );
      await _openTab(tester, 3);

      await tapVisible(tester, find.text('Limiti değiştir'));
      // All five choices fit a small phone.
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('6 saat'));
      await tapVisible(tester, find.text('Kaydet'));

      expect((await store.load())!.period, const Duration(hours: 6));
      expect(find.text('Son 6 saatte · şu an ₺0'), findsOneWidget);
    });

    testWidgets('a custom period: number and unit, within 1 hour to a year', (
      tester,
    ) async {
      useSmallPhone(tester);
      final store = InMemorySpendingLimitRepository();
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository(),
        spendingLimit: store,
      );
      await _openTab(tester, 3);

      await tapVisible(tester, find.text('Limiti değiştir'));
      await tapVisible(tester, find.text('Özel'));
      final count = find.byKey(const Key('profile.customPeriodCount'));

      await tester.enterText(count, '0');
      await tapVisible(tester, find.text('Kaydet'));
      expect(find.text('Bir sayı gir.'), findsOneWidget);

      await tester.enterText(count, '53');
      await tapVisible(
        tester,
        find.byKey(const Key('profile.customPeriodUnit')),
      );
      await tester.tap(find.text('hafta').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Kaydet'));
      expect(find.text('En az 1 saat, en fazla 365 gün.'), findsOneWidget);

      await tester.enterText(count, '3');
      await tapVisible(tester, find.text('Kaydet'));

      expect((await store.load())!.period, const Duration(days: 21));
      expect(find.text('Son 3 haftada · şu an ₺0'), findsOneWidget);
    });

    testWidgets('the limit can be switched off and on again', (tester) async {
      useSmallPhone(tester);
      final feed = FakeAuctionFeedRepository()
        ..discover = [liveAuction()]
        ..rooms['zenit'] = liveRoom()
        ..committed = const Money.kurus(195000);
      await pumpSignedIn(tester, feed: feed);

      await _openTab(tester, 3);
      await tapVisible(tester, find.text('Limiti değiştir'));
      await tapVisible(tester, find.byKey(const Key('profile.limitEnabled')));
      await tapVisible(tester, find.text('Kaydet'));

      expect(
        tester.widget<Text>(find.byKey(const Key('profile.limit'))).data,
        'Kapalı',
      );
      expect(find.text('Harcama limitin kapandı.'), findsOneWidget);
      expect(find.text('Sayacı sıfırla'), findsNothing);

      // ₺1.950 counted would block a ₺1.270 bid with the limit on.
      await _openTab(tester, 0);
      await tester.tap(find.text('Zenit-E analog fotoğraf makinesi (1978)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Limitine ulaştın'), findsNothing);
    });

    testWidgets('resetting the window asks first, then resets', (
      tester,
    ) async {
      useSmallPhone(tester);
      final store = InMemorySpendingLimitRepository();
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository(),
        spendingLimit: store,
      );
      await _openTab(tester, 3);

      await tapVisible(tester, find.text('Sayacı sıfırla'));
      expect(
        find.textContaining('Önde olduğun mezatlar sayılmaya devam eder.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Vazgeç'));
      expect(await store.load(), isNull);

      await tapVisible(tester, find.text('Sayacı sıfırla'));
      await tapVisible(tester, find.text('Sıfırla'));
      expect((await store.load())!.resetAt, isNotNull);
      expect(find.text('Sayaç sıfırlandı.'), findsOneWidget);
    });

    testWidgets('a limit that cannot be saved keeps the old one and says why', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository(),
        spendingLimit: _OfflineLimitRepository(),
      );
      await _openTab(tester, 3);

      await tapVisible(tester, find.text('Limiti değiştir'));
      await tester.enterText(
        find.byKey(const Key('profile.limitField')),
        '5.000',
      );
      await tapVisible(tester, find.text('Kaydet'));

      expect(
        tester.widget<Text>(find.byKey(const Key('profile.limit'))).data,
        '₺2.000',
      );
      expect(find.text(AuctionFailure.network.message), findsOneWidget);
      expect(
        find.text('Limitin son 1 günde en fazla ₺5.000 oldu.'),
        findsNothing,
      );
    });

    testWidgets('a higher limit unblocks a bid in the live room', (
      tester,
    ) async {
      useSmallPhone(tester);
      final feed = FakeAuctionFeedRepository()
        ..discover = [liveAuction()]
        ..rooms['zenit'] = liveRoom()
        ..committed = const Money.kurus(195000);
      await pumpSignedIn(tester, feed: feed);

      await _openTab(tester, 3);
      await tapVisible(tester, find.text('Limiti değiştir'));
      await tester.enterText(
        find.byKey(const Key('profile.limitField')),
        '10.000',
      );
      await tapVisible(tester, find.text('Kaydet'));

      await _openTab(tester, 0);
      await tester.tap(find.text('Zenit-E analog fotoğraf makinesi (1978)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Limitine ulaştın'), findsNothing);
    });

    testWidgets('connection lost while loading the total', (tester) async {
      useSmallPhone(tester);
      // The total cannot load; the screen still works and shows ₺0.
      await pumpSignedIn(tester, feed: _BrokenTotalFeed());
      await _openTab(tester, 3);

      expect(find.text('Son 1 günde · şu an ₺0'), findsOneWidget);
      expect(find.text('Limiti değiştir'), findsOneWidget);
    });
  });
}

class _OfflineLimitRepository extends InMemorySpendingLimitRepository {
  @override
  Future<void> save(SpendingLimit limit) =>
      Future.error(AuctionFailure.network);
}

class _BrokenTotalFeed extends FakeAuctionFeedRepository {
  @override
  Stream<Money> watchCommitted() => Stream.error(AuctionFailure.network);
}
