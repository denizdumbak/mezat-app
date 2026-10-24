// Renders every screen at phone size with the real fonts and writes PNGs, so
// the design can be reviewed without a device:
//   flutter test test_screenshots --update-goldens
// Output: test_screenshots/goldens/*.png (git-ignored; rendering differs
// between machines, so these are for looking at, not for comparing).
@Tags(['screenshots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/auction_feed_repository.dart';
import 'package:mezat_app/data/mock_auction_feed_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';

import '../test/helpers/app_fonts.dart';
import '../test/helpers/fakes.dart';
import '../test/helpers/sample_data.dart';

/// iPhone 14-ish: 390×844 logical pixels, written at 2×.
Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

FakeProfileRepository _profiles([String username = 'deniz']) =>
    FakeProfileRepository()..profiles[me] = Profile(id: me, username: username);

FakeAuctionFeedRepository _feed() => FakeAuctionFeedRepository()
  ..discover = [
    liveAuction(),
    liveAuction(
      id: 'kilim',
      title: 'El dokuması Uşak kilimi, 120×180 cm',
      seller: 'kilim_evi',
      price: const Money.kurus(480000),
      viewers: 64,
    ),
    upcomingAuction(),
    upcomingAuction(
      id: 'tutunamayanlar',
      title: 'Tutunamayanlar, ilk baskı (1972)',
      seller: 'sahaf_kadikoy',
      price: const Money.kurus(200000),
      startsIn: const Duration(days: 1),
    ),
  ]
  ..myScheduled = [
    upcomingAuction(
      id: 'cezve',
      title: 'Pirinç cezve takımı, el işi',
      seller: 'deniz',
      price: const Money.kurus(40000),
      startsIn: const Duration(minutes: 30),
    ),
  ]
  ..rooms['canon'] = liveRoom()
  ..committed = const Money.kurus(30000);

/// The app's demo catalogue (MockAuctionFeedRepository, with the photos in
/// assets/mock/) as a fixed snapshot: the lists, the Canon room and a
/// committed total.
Future<FakeAuctionFeedRepository> _catalogue(WidgetTester tester) async {
  late FakeAuctionFeedRepository feed;
  await tester.runAsync(() async {
    final mock = MockAuctionFeedRepository(
      currentUser: () => (id: me, username: 'deniz'),
      simulate: false,
    );
    feed = FakeAuctionFeedRepository()
      ..discover = await mock.watchDiscover().first
      ..myScheduled = await mock.watchMyScheduled().first
      ..rooms['canon'] = await mock.watchRoom('canon').first
      ..committed = const Money.kurus(30000);
    mock.dispose();
  });
  return feed;
}

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  // Photos decode off the fake clock; wait for every one on screen.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

/// Signed in on [feed], or on the demo catalogue when none is given. Most
/// demo items cost more than the default ₺2.000 limit, so the catalogue gets
/// a ₺50.000 one; the limit screenshot (09) has its own feed.
Future<void> _signedIn(
  WidgetTester tester, {
  FakeAuctionFeedRepository? feed,
  String username = 'deniz',
}) async {
  final limits = InMemorySpendingLimitRepository();
  if (feed == null) {
    await limits.save(
      const SpendingLimit(
        amount: Money.kurus(5000000),
        period: Duration(days: 1),
        enabled: true,
      ),
    );
  }
  await pumpApp(
    tester,
    auth: FakeAuthRepository(signedInAs: me),
    profiles: _profiles(username),
    feed: feed ?? await _catalogue(tester),
    spendingLimit: limits,
  );
}

Future<void> _openRoom(WidgetTester tester) async {
  await tester.tap(find.text('Canon AE-1 Program, 50mm f/1.8 lens').first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('01 sign in', (tester) async {
    await _phone(tester);
    await pumpApp(tester, auth: FakeAuthRepository());
    await _snap(tester, '01_sign_in');
  });

  testWidgets('02 discover', (tester) async {
    await _phone(tester);
    await _signedIn(tester);
    await _snap(tester, '02_discover');
  });

  testWidgets('03 discover, empty', (tester) async {
    await _phone(tester);
    await _signedIn(tester, feed: FakeAuctionFeedRepository());
    await _snap(tester, '03_discover_empty');
  });

  testWidgets('04 live list', (tester) async {
    await _phone(tester);
    await _signedIn(tester);
    await tester.tap(find.byKey(const Key('tab.1')));
    await _snap(tester, '04_live_list');
  });

  testWidgets('05 sell', (tester) async {
    await _phone(tester);
    await _signedIn(tester);
    await tester.tap(find.byKey(const Key('tab.2')));
    await _snap(tester, '05_sell');
  });

  testWidgets('06 profile', (tester) async {
    await _phone(tester);
    await _signedIn(tester);
    await tester.tap(find.byKey(const Key('tab.3')));
    await _snap(tester, '06_profile');
  });

  testWidgets('07 live room', (tester) async {
    await _phone(tester);
    await _signedIn(tester);
    await _openRoom(tester);
    await _snap(tester, '07_live_room');
  });

  testWidgets('08 live room, leading with a long name and 6 digits', (
    tester,
  ) async {
    await _phone(tester);
    final feed = _feed()
      ..rooms['canon'] = liveRoom(
        seller: longUsername,
        price: sixDigits,
        endsIn: const Duration(seconds: 8),
        bids: [
          bid('b9', 'deniz', 999999, bidderId: me),
          bid('b8', longUsername, 999990),
        ],
      )
      ..committed = sixDigits;
    await _signedIn(tester, feed: feed);
    await _openRoom(tester);
    await _snap(tester, '08_live_room_long');
  });

  testWidgets('11 spending limit sheet, custom period', (tester) async {
    await _phone(tester);
    await _signedIn(tester);
    await tester.tap(find.byKey(const Key('tab.3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limiti değiştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Özel'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile.customPeriodCount')),
      '36',
    );
    // Hide the keyboard focus so the whole sheet shows.
    FocusManager.instance.primaryFocus?.unfocus();
    await _snap(tester, '11_limit_sheet');
  });

  testWidgets('09 live room, spending limit reached', (tester) async {
    await _phone(tester);
    final feed = _feed()..committed = const Money.kurus(195000);
    await _signedIn(tester, feed: feed);
    await _openRoom(tester);
    await _snap(tester, '09_live_room_limit');
  });

  testWidgets('10 high bid confirmation', (tester) async {
    await _phone(tester);
    final feed = _feed()..committed = const Money.kurus(0);
    await _signedIn(tester, feed: feed);
    await _openRoom(tester);
    await tester.tap(find.text('+₺10 teklif ver'));
    await _snap(tester, '10_confirm');
  });

  testWidgets('12 connection lost', (tester) async {
    await _phone(tester);
    final feed = _feed()..rooms['canon'] = liveRoom(connected: false);
    await _signedIn(tester, feed: feed);
    await _openRoom(tester);
    await _snap(tester, '12_connection_lost');
  });

  testWidgets('13 sold', (tester) async {
    await _phone(tester);
    final feed = _feed();
    await _signedIn(tester, feed: feed);
    await _openRoom(tester);
    feed
      ..rooms['canon'] = liveRoom(
        ended: true,
        endsIn: Duration.zero,
        sold: const SoldResult(
          winnerId: 'bot-retro_avcisi',
          winnerUsername: 'retro_avcisi',
          amount: Money.kurus(125000),
        ),
      )
      ..emit();
    await _snap(tester, '13_sold');
  });

  testWidgets('14 create auction', (tester) async {
    await _phone(tester);
    await _signedIn(tester);
    await tester.tap(find.byKey(const Key('tab.2')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Mezat oluştur'));
    await _snap(tester, '14_create');
  });
}
