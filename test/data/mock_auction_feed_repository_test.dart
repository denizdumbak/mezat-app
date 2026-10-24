import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/auction_rules.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/mock_auction_feed_repository.dart';

/// The mock follows the server rules, so the screens built on it behave
/// like the real thing will.
void main() {
  late DateTime now;
  late MockAuctionFeedRepository repository;
  const user = (id: 'user-1', username: 'deniz');

  setUp(() {
    now = DateTime(2026, 10, 24, 20);
    repository = MockAuctionFeedRepository(
      currentUser: () => user,
      simulate: false,
      clock: () => now,
    );
  });
  tearDown(() => repository.dispose());

  test(
    'discover lists live auctions first, not your own upcoming ones',
    () async {
      final list = await repository.watchDiscover().first;
      expect(list.first.isLive, isTrue);
      expect(list.where((a) => a.id == 'cezve'), isEmpty);
      final mine = await repository.watchMyScheduled().first;
      expect(mine.single.id, 'cezve');
    },
  );

  test('a valid bid raises the price and leads', () async {
    final before = await repository.watchRoom('zenit').first;
    await repository.placeBid(
      'zenit',
      before.currentPrice + before.minIncrement,
    );

    final after = await repository.watchRoom('zenit').first;
    expect(after.currentPrice, before.currentPrice + before.minIncrement);
    expect(after.leadingBid!.bidderId, user.id);
    expect(await repository.watchCommittedToday().first, after.currentPrice);
  });

  test('a bid below current price + minimum step is BID_TOO_LOW', () async {
    final room = await repository.watchRoom('zenit').first;
    await expectLater(
      repository.placeBid('zenit', room.currentPrice),
      throwsA(AuctionFailure.bidTooLow),
    );
  });

  test('the seller cannot bid on their own auction', () async {
    await repository.startAuction('cezve');
    final room = await repository.watchRoom('cezve').first;
    await expectLater(
      repository.placeBid('cezve', room.currentPrice + room.minIncrement),
      throwsA(AuctionFailure.sellerCannotBid),
    );
  });

  test('a bid in the last 30 seconds extends the end by 30', () async {
    final room = await repository.watchRoom('zenit').first;
    now = room.endsAt.subtract(const Duration(seconds: 10));
    await repository.placeBid('zenit', room.currentPrice + room.minIncrement);

    final after = await repository.watchRoom('zenit').first;
    expect(after.endsAt, room.endsAt.add(antiSnipingExtension));
  });

  test('an upcoming auction is not open for bids', () async {
    await expectLater(
      repository.placeBid('telkari', const Money.kurus(100000)),
      throwsA(AuctionFailure.auctionNotLive),
    );
  });
}
