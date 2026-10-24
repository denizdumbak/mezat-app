// Runs SupabaseAuctionFeedRepository against the local Supabase stack: what
// the lists show to whom, starting an auction, the live room and bidding.
//
// Needs `npx supabase start`. Not part of `flutter test`:
//   flutter test test_supabase --dart-define-from-file=.env
@Tags(['supabase'])
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/photo_picker.dart';
import 'package:mezat_app/data/auction_feed_repository.dart';
import 'package:mezat_app/data/auction_repository.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:mezat_app/data/supabase_auction_feed_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final run = Random().nextInt(1 << 32).toRadixString(36);
  const password = 'Passw0rd!x';

  late SupabaseClient seller;
  late SupabaseClient buyer;
  late String sellerId;

  Future<SupabaseClient> signUp(String name) async {
    final client = newClient();
    await AuthRepository(
      client.auth,
    ).signUp(email: '${name}_$run@example.com', password: password);
    await ProfileRepository(client).setUsername(
      userId: client.auth.currentUser!.id,
      username: '${name}_$run',
    );
    return client;
  }

  Future<String> createAuction({
    String title = 'Analog kamera',
    Money minIncrement = const Money.kurus(1000),
    List<Money> bidIncrements = const [],
    String? imagePath,
  }) => AuctionRepository(seller).create(
    NewAuction(
      title: '$title $run',
      description: '',
      startPrice: const Money.kurus(125050),
      minIncrement: minIncrement,
      bidIncrements: bidIncrements,
      durationMinutes: 5,
      startsAt: DateTime.now().add(const Duration(hours: 1)),
    ),
    imagePath: imagePath,
  );

  AuctionSummary? find(List<AuctionSummary> list, String id) =>
      list.where((a) => a.id == id).firstOrNull;

  setUpAll(() async {
    seller = await signUp('fs');
    buyer = await signUp('fb');
    sellerId = seller.auth.currentUser!.id;
  });

  tearDownAll(() async {
    await seller.dispose();
    await buyer.dispose();
  });

  test(
    'a new auction is in the seller\'s planned list, with its photo',
    () async {
      final path = await AuctionRepository(seller).uploadImage(
        userId: sellerId,
        photo: PickedPhoto(
          bytes: Uint8List(16),
          contentType: 'image/jpeg',
          extension: 'jpg',
        ),
      );
      final id = await createAuction(imagePath: path);

      final mine = await SupabaseAuctionFeedRepository(
        seller,
      ).watchMyScheduled().first;
      final auction = find(mine, id)!;
      expect(auction.isLive, isFalse);
      expect(auction.currentPrice, const Money.kurus(125050));
      expect(auction.imageUrl, endsWith('/auction-images/$path'));
    },
  );

  test('others see it as upcoming in Keşfet; the seller does not', () async {
    final id = await createAuction();

    final forBuyer = await SupabaseAuctionFeedRepository(
      buyer,
    ).watchDiscover().first;
    expect(find(forBuyer, id)!.sellerUsername, 'fs_$run');
    expect(find(forBuyer, id)!.isLive, isFalse);

    final forSeller = await SupabaseAuctionFeedRepository(
      seller,
    ).watchDiscover().first;
    expect(find(forSeller, id), isNull);
  });

  test('only the seller can start it; then it is live for everyone', () async {
    final id = await createAuction();

    await expectLater(
      SupabaseAuctionFeedRepository(buyer).startAuction(id),
      throwsA(AuctionFailure.notSeller),
    );
    await SupabaseAuctionFeedRepository(seller).startAuction(id);

    final forBuyer = await SupabaseAuctionFeedRepository(
      buyer,
    ).watchDiscover().first;
    expect(find(forBuyer, id)!.isLive, isTrue);
    final mine = await SupabaseAuctionFeedRepository(
      seller,
    ).watchMyScheduled().first;
    expect(find(mine, id), isNull);
    await expectLater(
      SupabaseAuctionFeedRepository(seller).startAuction(id),
      throwsA(AuctionFailure.notScheduled),
    );
  });

  test('the live room reads the auction, with no bids yet', () async {
    final id = await createAuction(minIncrement: const Money.kurus(2500));
    await SupabaseAuctionFeedRepository(seller).startAuction(id);

    final room = await SupabaseAuctionFeedRepository(buyer).watchRoom(id).first;
    expect(room.title, 'Analog kamera $run');
    expect(room.sellerId, sellerId);
    expect(room.sellerUsername, 'fs_$run');
    expect(room.currentPrice, const Money.kurus(125050));
    expect(room.minIncrement, const Money.kurus(2500));
    // ₺25 minimum: the default +₺10 chip would be refused by the server.
    expect(room.increments, const [
      Money.kurus(2500),
      Money.kurus(12500),
      Money.kurus(25000),
    ]);
    expect(room.bids, isEmpty);
    expect(room.ended, isFalse);
    expect(
      room.endsAt.difference(DateTime.now()).inMinutes,
      inInclusiveRange(4, 5),
    );
  });

  test("the room shows the seller's own increment chips", () async {
    const chips = [Money.kurus(2500), Money.kurus(7550), Money.kurus(100000)];
    final id = await createAuction(
      minIncrement: const Money.kurus(2500),
      bidIncrements: chips,
    );
    await SupabaseAuctionFeedRepository(seller).startAuction(id);

    final room = await SupabaseAuctionFeedRepository(buyer).watchRoom(id).first;
    expect(room.increments, chips);
  });

  test('chips below the minimum are refused with their own message', () async {
    await expectLater(
      createAuction(
        minIncrement: const Money.kurus(2500),
        bidIncrements: const [Money.kurus(1000)],
      ),
      throwsA(AuctionFailure.invalidIncrements),
    );
  });

  test('when the time is up the room ends and Keşfet drops it', () async {
    final id = await createAuction();
    await SupabaseAuctionFeedRepository(seller).startAuction(id);
    // Ten minutes later, as far as the repository can tell.
    final later = SupabaseAuctionFeedRepository(
      buyer,
      clock: () => DateTime.now().add(const Duration(minutes: 10)),
    );

    expect((await later.watchRoom(id).first).ended, isTrue);
    expect(find(await later.watchDiscover().first, id), isNull);
  });

  test(
    'a planned auction has no room yet; a missing one is notFound',
    () async {
      final id = await createAuction();
      final repository = SupabaseAuctionFeedRepository(buyer);

      await expectLater(
        repository.watchRoom(id).first,
        throwsA(AuctionFailure.auctionNotLive),
      );
      await expectLater(
        repository.watchRoom('00000000-0000-0000-0000-000000000000').first,
        throwsA(AuctionFailure.notFound),
      );
    },
  );

  group('bidding', () {
    /// A live auction at ₺1.250,50 with a ₺25 minimum step.
    Future<String> liveAuction() async {
      final id = await createAuction(minIncrement: const Money.kurus(2500));
      await SupabaseAuctionFeedRepository(seller).startAuction(id);
      return id;
    }

    test('a bid moves the price, joins the feed and counts against the '
        'limit; the room reloads by itself', () async {
      final id = await liveAuction();
      final bidder = await signUp('fd');
      addTearDown(bidder.dispose);
      final repository = SupabaseAuctionFeedRepository(bidder);
      final rooms = StreamIterator(repository.watchRoom(id));
      expect(await rooms.moveNext(), isTrue);
      expect(rooms.current.bids, isEmpty);

      await repository.placeBid(id, const Money.kurus(127550));

      expect(await rooms.moveNext(), isTrue);
      final room = rooms.current;
      expect(room.currentPrice, const Money.kurus(127550));
      expect(room.bids.single.amount, const Money.kurus(127550));
      expect(room.bids.single.username, 'fd_$run');
      expect(room.bids.single.bidderId, bidder.auth.currentUser!.id);
      await rooms.cancel();

      // The buyer leads it, so it counts against their limit.
      expect(
        await repository.watchCommitted().first,
        const Money.kurus(127550),
      );
    });

    test("the server's refusals arrive as their own failures", () async {
      final id = await liveAuction();
      final bidder = await signUp('fe');
      addTearDown(bidder.dispose);
      final repository = SupabaseAuctionFeedRepository(bidder);

      await expectLater(
        repository.placeBid(id, const Money.kurus(126000)),
        throwsA(AuctionFailure.bidTooLow),
      );
      await expectLater(
        SupabaseAuctionFeedRepository(
          seller,
        ).placeBid(id, const Money.kurus(127550)),
        throwsA(AuctionFailure.sellerCannotBid),
      );
      await repository.placeBid(id, const Money.kurus(127550));
      await expectLater(
        repository.placeBid(id, const Money.kurus(130050)),
        throwsA(AuctionFailure.alreadyWinning),
      );
    });

    test('a bid over the default ₺2.000 limit is refused', () async {
      final id = await liveAuction();
      final other = await signUp('fc');
      addTearDown(other.dispose);

      await expectLater(
        SupabaseAuctionFeedRepository(
          other,
        ).placeBid(id, const Money.kurus(200100)),
        throwsA(AuctionFailure.spendingLimitExceeded),
      );
    });
  });
}
