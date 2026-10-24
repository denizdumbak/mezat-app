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
import 'package:mezat_app/data/profile_repository.dart';

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
  ..rooms['zenit'] = liveRoom()
  ..committed = const Money.kurus(30000);

Future<void> _snap(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

Future<void> _signedIn(
  WidgetTester tester, {
  FakeAuctionFeedRepository? feed,
  String username = 'deniz',
}) => pumpApp(
  tester,
  auth: FakeAuthRepository(signedInAs: me),
  profiles: _profiles(username),
  feed: feed ?? _feed(),
);

Future<void> _openRoom(WidgetTester tester) async {
  await tester.tap(find.text('Zenit-E analog fotoğraf makinesi (1978)').first);
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
      ..rooms['zenit'] = liveRoom(
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

  testWidgets('09 live room, daily limit reached', (tester) async {
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
    final feed = _feed()..rooms['zenit'] = liveRoom(connected: false);
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
      ..rooms['zenit'] = liveRoom(
        ended: true,
        endsIn: Duration.zero,
        sold: const SoldResult(
          winnerId: 'bot-plakci_baris',
          winnerUsername: 'plakci_baris',
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
