// Runs SupabaseSpendingLimitRepository against the local Supabase stack: the
// limit round-trips exactly, each user sees only their own, and place_bid
// enforces the stored value.
//
// Needs `npx supabase start`. Not part of `flutter test`:
//   flutter test test_supabase --dart-define-from-file=.env
@Tags(['supabase'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/auction_repository.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

void main() {
  final run = Random().nextInt(1 << 32).toRadixString(36);
  const password = 'Passw0rd!x';

  late SupabaseClient seller;
  late SupabaseClient bidder;
  late SupabaseClient other;

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

  setUpAll(() async {
    seller = await signUp('limseller');
    bidder = await signUp('limbidder');
    other = await signUp('limother');
  });

  tearDownAll(() async {
    await seller.dispose();
    await bidder.dispose();
    await other.dispose();
  });

  test('no limit until one is saved; then it reads back exactly', () async {
    final repository = SupabaseSpendingLimitRepository(bidder);
    expect(await repository.load(), isNull);

    await repository.save(const Money.kurus(150050));
    expect(await repository.load(), const Money.kurus(150050));

    await repository.save(const Money.kurus(30000));
    expect(await repository.load(), const Money.kurus(30000));
  });

  test('another user cannot see the limit', () async {
    expect(await SupabaseSpendingLimitRepository(other).load(), isNull);
  });

  test('a zero limit is refused', () async {
    await expectLater(
      SupabaseSpendingLimitRepository(other).save(Money.zero),
      throwsA(AuctionFailure.invalidInput),
    );
  });

  test('place_bid enforces the saved limit', () async {
    // bidder's limit is ₺300 from the first test.
    final id = await AuctionRepository(seller).create(
      NewAuction(
        title: 'Limit $run',
        description: 'Test',
        startPrice: const Money.kurus(10000),
        minIncrement: const Money.kurus(1000),
        durationMinutes: 30,
        startsAt: DateTime.now(),
      ),
    );
    await seller.rpc('start_auction', params: {'p_auction_id': id});

    await expectLater(
      bidder.rpc(
        'place_bid',
        params: {'p_auction_id': id, 'p_amount': '300.01'},
      ),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          'DAILY_LIMIT_EXCEEDED',
        ),
      ),
    );
    await bidder.rpc(
      'place_bid',
      params: {'p_auction_id': id, 'p_amount': '300.00'},
    );
    expect(await bidder.rpc('committed_today'), 300);
  });
}
