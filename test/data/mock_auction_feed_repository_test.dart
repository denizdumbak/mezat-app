import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/auction_rules.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/mock_auction_feed_repository.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';

/// The mock follows the server rules, so the screens built on it behave
/// like the real thing will.
void main() {
  late DateTime now;
  late MockAuctionFeedRepository repository;
  late SpendingLimit limit;
  const user = (id: 'user-1', username: 'deniz');

  setUp(() {
    now = DateTime(2026, 10, 24, 20);
    // The demo prices are above the default ₺2.000; the limit test lowers it.
    limit = SpendingLimit.defaults.copyWith(
      amount: const Money.kurus(10000000),
    );
    repository = MockAuctionFeedRepository(
      currentUser: () => user,
      simulate: false,
      clock: () => now,
      spendingLimit: () => limit,
    );
  });
  tearDown(() => repository.dispose());

  test(
    'discover lists live auctions first, not your own upcoming ones',
    () async {
      final list = await repository.watchDiscover().first;
      expect(list.first.isLive, isTrue);
      expect(list.where((a) => a.id == 'daktilo'), isEmpty);
      final mine = await repository.watchMyScheduled().first;
      expect(mine.single.id, 'daktilo');
    },
  );

  test('the demo catalogue: ten auctions, each with a bundled photo', () async {
    final discover = await repository.watchDiscover().first;
    final mine = await repository.watchMyScheduled().first;
    final shown = [...discover, ...mine];
    expect(shown.where((a) => a.isLive), hasLength(4));
    expect(shown.where((a) => !a.isLive), hasLength(4));
    // Sold ones are not listed, but their rooms still open.
    expect(shown.where((a) => a.isEnded), isEmpty);
    final sold = await repository.watchRoom('lens').first;
    expect(sold.sold!.amount, const Money.kurus(160000));

    for (final auction in shown) {
      expect(auction.imageUrl, startsWith('assets/mock/'));
      expect(File(auction.imageUrl!).existsSync(), isTrue, reason: auction.id);
    }
    // Live cards show the time left.
    expect(shown.where((a) => a.isLive && a.endsAt == null), isEmpty);
  });

  test('a valid bid raises the price and leads', () async {
    final before = await repository.watchRoom('canon').first;
    await repository.placeBid(
      'canon',
      before.currentPrice + before.minIncrement,
    );

    final after = await repository.watchRoom('canon').first;
    expect(after.currentPrice, before.currentPrice + before.minIncrement);
    expect(after.leadingBid!.bidderId, user.id);
    expect(await repository.watchCommitted().first, after.currentPrice);
  });

  test('a bid below current price + minimum step is BID_TOO_LOW', () async {
    final room = await repository.watchRoom('canon').first;
    await expectLater(
      repository.placeBid('canon', room.currentPrice),
      throwsA(AuctionFailure.bidTooLow),
    );
  });

  test('the seller cannot bid on their own auction', () async {
    await repository.startAuction('daktilo');
    final room = await repository.watchRoom('daktilo').first;
    await expectLater(
      repository.placeBid('daktilo', room.currentPrice + room.minIncrement),
      throwsA(AuctionFailure.sellerCannotBid),
    );
  });

  test('a bid in the last 30 seconds extends the end by 30', () async {
    final room = await repository.watchRoom('canon').first;
    now = room.endsAt.subtract(const Duration(seconds: 10));
    await repository.placeBid('canon', room.currentPrice + room.minIncrement);

    final after = await repository.watchRoom('canon').first;
    expect(after.endsAt, room.endsAt.add(antiSnipingExtension));
  });

  test('the leader cannot bid again, as on the server', () async {
    final room = await repository.watchRoom('canon').first;
    await repository.placeBid('canon', room.currentPrice + room.minIncrement);
    final after = await repository.watchRoom('canon').first;

    await expectLater(
      repository.placeBid('canon', after.currentPrice + after.minIncrement),
      throwsA(AuctionFailure.alreadyWinning),
    );
  });

  test('a bid over the spending limit is refused, as on the server', () async {
    limit = SpendingLimit.defaults;
    final room = await repository.watchRoom('canon').first;
    await expectLater(
      repository.placeBid('canon', room.currentPrice + room.minIncrement),
      throwsA(AuctionFailure.spendingLimitExceeded),
    );
  });

  test('an upcoming auction is not open for bids', () async {
    await expectLater(
      repository.placeBid('walkman', const Money.kurus(100000)),
      throwsA(AuctionFailure.auctionNotLive),
    );
  });
}
