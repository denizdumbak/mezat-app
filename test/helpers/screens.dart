import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/auction_feed_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:mezat_app/features/live_room/bid_safety.dart';

import 'fakes.dart';
import 'sample_data.dart';

/// A small phone: 360×640 logical pixels. Overflowing layouts fail the test.
void useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The whole app, signed in with a username, on the given feed.
Future<void> pumpSignedIn(
  WidgetTester tester, {
  required FakeAuctionFeedRepository feed,
  String username = 'deniz',
  SpendingLimitRepository? spendingLimit,
}) => pumpApp(
  tester,
  auth: FakeAuthRepository(signedInAs: me),
  profiles: FakeProfileRepository()
    ..profiles[me] = Profile(id: me, username: username),
  feed: feed,
  spendingLimit: spendingLimit,
);

/// Signed in, then into [room] from the Keşfet strip.
Future<FakeAuctionFeedRepository> openRoom(
  WidgetTester tester,
  LiveRoom room, {
  Money? committed,
  SpendingLimitRepository? spendingLimit,
}) async {
  final feed = FakeAuctionFeedRepository()
    ..discover = [liveAuction(id: room.auctionId, title: room.title)]
    ..rooms[room.auctionId] = room;
  if (committed != null) feed.committed = committed;
  await pumpSignedIn(tester, feed: feed, spendingLimit: spendingLimit);
  await tester.tap(find.text(room.title).first);
  await tester.pumpAndSettle();
  return feed;
}

/// Taps a button that may be below the fold.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
