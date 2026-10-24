import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/widgets/app_loader.dart';
import 'package:mezat_app/core/widgets/skeleton.dart';
import 'package:mezat_app/data/auction_feed_repository.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';
import 'package:mezat_app/features/auctions/discover_screen.dart';
import 'package:mezat_app/features/live_room/live_room_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/sample_data.dart';
import '../helpers/screens.dart';

const _longTitle =
    'Çok uzun başlıklı bir ürün: el yapımı, gümüş kaplama, antika '
    'İstanbul işi kahve takımı ve tepsisi';

/// The limit as the Profil screen shows it: a [PriceLabel] or plain text.
String _limitText(WidgetTester tester) {
  final text = tester.widget<Text>(
    find
        .descendant(
          of: find.byKey(const Key('profile.limit')),
          matching: find.byType(Text),
          matchRoot: true,
        )
        .first,
  );
  return text.data ?? text.textSpan!.toPlainText();
}

/// Scrolls the page (not a sideways row) until [finder] is built.
Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ),
    );

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
  group('tabs', () {
    testWidgets('Keşfet, Sat, Tekliflerim, Profil; no Canlı tab', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: FakeAuctionFeedRepository());

      for (final (i, label) in [
        'Keşfet',
        'Sat',
        'Tekliflerim',
        'Profil',
      ].indexed) {
        expect(
          find.descendant(
            of: find.byKey(Key('tab.$i')),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('tab.4')), findsNothing);
      expect(find.text('Canlı'), findsNothing);
      expect(find.text('Yayın aç'), findsNothing);
    });
  });

  group('Keşfet', () {
    testWidgets('long names, long titles and 6-digit prices fit', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: _edgeCaseFeed(), username: longUsername);

      expect(find.byType(DiscoverScreen), findsOneWidget);
      expect(find.text('@$longUsername'), findsWidgets);
      expect(find.text('₺999.999'), findsWidgets);
      expect(find.text('CANLI · 12 B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('logo and avatar on top; no big title', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: FakeAuctionFeedRepository());

      expect(find.text('mezat'), findsOneWidget);
      expect(find.text('Keşfet'), findsOneWidget); // the tab label only
      await tester.tap(find.byKey(const Key('discover.avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Harcama limiti'), findsOneWidget);
    });

    testWidgets('live and upcoming are separate sections', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()
          ..discover = [liveAuction(), upcomingAuction()],
      );

      expect(find.text('Şimdi canlı'), findsOneWidget);
      await _scrollTo(tester, find.text('Yaklaşan'));
      expect(find.text('Yaklaşan'), findsOneWidget);
      expect(find.textContaining('Bugün'), findsOneWidget);
    });

    testWidgets('live cards: two per row, busiest first', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()
          ..discover = [
            liveAuction(id: 'quiet', title: 'Az izlenen', viewers: 10),
            liveAuction(id: 'busy', title: 'Çok izlenen', viewers: 500),
          ],
      );

      final busy = tester.getTopLeft(find.text('Çok izlenen'));
      final quiet = tester.getTopLeft(find.text('Az izlenen'));
      expect(busy.dy, quiet.dy);
      expect(busy.dx, lessThan(quiet.dx));
    });

    testWidgets('"Tümü" only with more than six live auctions', (tester) async {
      // Tall enough that every card is built.
      tester.view.physicalSize = const Size(1080, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      List<AuctionSummary> live(int n) => [
        for (var i = 0; i < n; i++)
          liveAuction(id: 'a$i', title: 'Ürün $i', viewers: 100 - i),
      ];

      final feed = FakeAuctionFeedRepository()..discover = live(6);
      await pumpSignedIn(tester, feed: feed);
      expect(find.text('Tümü'), findsOneWidget); // the category chip
      expect(find.widgetWithText(TextButton, 'Tümü'), findsNothing);

      feed
        ..discover = live(7)
        ..emit();
      await tester.pumpAndSettle();
      expect(find.text('Ürün 5'), findsOneWidget);
      expect(find.text('Ürün 6'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Tümü'));
      await tester.pumpAndSettle();
      expect(find.text('Ürün 6'), findsOneWidget);
    });

    testWidgets('search filters by title and seller, here on the phone', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()
          ..discover = [
            liveAuction(),
            liveAuction(
              id: 'seiko',
              title: 'Seiko 5 otomatik saat',
              seller: 'saatciusta',
            ),
            upcomingAuction(),
          ],
      );
      final search = find.byKey(const Key('discover.search'));

      await tester.enterText(search, 'SEİKO');
      await tester.pumpAndSettle();
      expect(find.text('Seiko 5 otomatik saat'), findsOneWidget);
      expect(find.text('Canon AE-1 Program, 50mm f/1.8 lens'), findsNothing);
      expect(find.text('Yaklaşan'), findsNothing);

      await tester.enterText(search, 'kasetcafe');
      await tester.pumpAndSettle();
      expect(
        find.text('Sony Walkman WM-F10, kasetli, çalışır'),
        findsOneWidget,
      );

      await tester.enterText(search, 'gramofon');
      await tester.pumpAndSettle();
      expect(find.text('Sonuç yok'), findsOneWidget);
      await tester.tap(find.text('Filtreyi temizle'));
      await tester.pumpAndSettle();
      expect(find.text('Canon AE-1 Program, 50mm f/1.8 lens'), findsOneWidget);
    });

    testWidgets('category chips filter; Tümü shows everything', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()
          ..discover = [
            liveAuction(),
            liveAuction(id: 'seiko', title: 'Seiko 5 otomatik saat'),
          ],
      );

      await tester.tap(find.byKey(const Key('category.saat')));
      await tester.pumpAndSettle();
      expect(find.text('Seiko 5 otomatik saat'), findsOneWidget);
      expect(find.text('Canon AE-1 Program, 50mm f/1.8 lens'), findsNothing);

      await tester.tap(find.byKey(const Key('category.all')));
      await tester.pumpAndSettle();
      expect(find.text('Canon AE-1 Program, 50mm f/1.8 lens'), findsOneWidget);
    });

    testWidgets('a live card opens the live room', (tester) async {
      useSmallPhone(tester);
      final feed = FakeAuctionFeedRepository()
        ..discover = [liveAuction()]
        ..rooms['canon'] = liveRoom();
      await pumpSignedIn(tester, feed: feed);

      await tester.tap(find.text('Canon AE-1 Program, 50mm f/1.8 lens'));
      await tester.pumpAndSettle();

      expect(find.byType(LiveRoomScreen), findsOneWidget);
    });

    testWidgets('nothing live: says so and points to what is coming', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()..discover = [upcomingAuction()],
      );

      expect(find.text('Şu an canlı mezat yok'), findsOneWidget);
      await tester.tap(find.text('Yaklaşanlara bak'));
      await tester.pumpAndSettle();
      expect(find.text('Yaklaşan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty: says so and offers to sell', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: FakeAuctionFeedRepository());

      expect(find.text('Şu an mezat yok'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sat'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(FilledButton, 'Mezat oluştur'),
        findsOneWidget,
      );
    });

    testWidgets('loading: card skeletons, not a spinner', (tester) async {
      useSmallPhone(tester);
      // The shimmer stands still with reduced motion, so the test can settle.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()..discoverPending = true,
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.byType(AppLoader), findsNothing);
      expect(tester.takeException(), isNull);
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

  group('Sat', () {
    testWidgets('titled Sat; one primary action; planned auctions listed', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: _edgeCaseFeed());
      await _openTab(tester, 1);

      expect(find.text('Sat'), findsWidgets);
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
      await _openTab(tester, 1);

      await tester.tap(find.text('Yayını başlat'));
      await tester.pumpAndSettle();

      expect(feed.started, ['mine']);
      expect(find.byType(LiveRoomScreen), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      useSmallPhone(tester);
      await pumpSignedIn(tester, feed: FakeAuctionFeedRepository());
      await _openTab(tester, 1);

      expect(find.text('Henüz planlanmış mezatın yok.'), findsOneWidget);
    });
  });

  group('Tekliflerim', () {
    testWidgets('empty for now: says so and leads to the live auctions', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpSignedIn(
        tester,
        feed: FakeAuctionFeedRepository()..discover = [liveAuction()],
      );
      await _openTab(tester, 2);

      expect(find.text('Henüz teklif vermedin'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Canlı mezatlara göz at'));
      await tester.pumpAndSettle();
      expect(find.text('Şimdi canlı'), findsOneWidget);
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

      expect(_limitText(tester), '₺2.000');

      await tapVisible(tester, find.text('Limiti değiştir'));
      await tester.enterText(find.byKey(const Key('profile.limitField')), '');
      await tapVisible(tester, find.text('Kaydet'));
      expect(find.text('Bir tutar gir.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('profile.limitField')),
        '5.000',
      );
      await tapVisible(tester, find.text('Kaydet'));

      expect(_limitText(tester), '₺5.000');
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
        ..rooms['canon'] = liveRoom()
        ..committed = const Money.kurus(195000);
      await pumpSignedIn(tester, feed: feed);

      await _openTab(tester, 3);
      await tapVisible(tester, find.text('Limiti değiştir'));
      await tapVisible(tester, find.byKey(const Key('profile.limitEnabled')));
      await tapVisible(tester, find.text('Kaydet'));

      expect(_limitText(tester), 'Kapalı');
      expect(find.text('Harcama limitin kapandı.'), findsOneWidget);
      expect(find.text('Sayacı sıfırla'), findsNothing);

      // ₺1.950 counted would block a ₺1.270 bid with the limit on.
      await _openTab(tester, 0);
      await tester.tap(find.text('Canon AE-1 Program, 50mm f/1.8 lens'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Limitine ulaştın'), findsNothing);
    });

    testWidgets('resetting the window asks first, then resets', (tester) async {
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

      expect(_limitText(tester), '₺2.000');
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
        ..rooms['canon'] = liveRoom()
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
      await tester.tap(find.text('Canon AE-1 Program, 50mm f/1.8 lens'));
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
