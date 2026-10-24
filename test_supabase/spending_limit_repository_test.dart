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

  test('no settings until saved; then they read back exactly', () async {
    final repository = SupabaseSpendingLimitRepository(bidder);
    expect(await repository.load(), isNull);

    for (final period in [
      ...SpendingLimit.presetPeriods,
      const Duration(hours: 36),
      const Duration(days: 365),
    ]) {
      final limit = SpendingLimit(
        amount: const Money.kurus(150050),
        period: period,
        enabled: false,
      );
      await repository.save(limit);
      expect(await repository.load(), limit, reason: '$period');
    }

    // Left on for the place_bid test below: ₺300 in 1 day.
    await repository.save(
      SpendingLimit(
        amount: const Money.kurus(30000),
        period: const Duration(days: 1),
        enabled: true,
      ),
    );
  });

  test('a reset is stored and kept when the settings change', () async {
    final repository = SupabaseSpendingLimitRepository(other);
    await repository.resetWindow();
    final reset = (await repository.load())!;
    expect(reset.resetAt, isNotNull);
    expect(reset.amount, SpendingLimit.defaults.amount);

    await repository.save(reset.copyWith(period: const Duration(hours: 6)));
    expect((await repository.load())!.resetAt, reset.resetAt);
  });

  test('another user cannot see the settings', () async {
    expect(
      (await SupabaseSpendingLimitRepository(other).load())!.amount,
      isNot(const Money.kurus(30000)),
    );
    expect(await SupabaseSpendingLimitRepository(seller).load(), isNull);
  });

  test('a zero amount or a period over a year is refused', () async {
    final repository = SupabaseSpendingLimitRepository(seller);
    await expectLater(
      repository.save(SpendingLimit.defaults.copyWith(amount: Money.zero)),
      throwsA(AuctionFailure.invalidInput),
    );
    await expectLater(
      repository.save(
        SpendingLimit.defaults.copyWith(period: const Duration(days: 366)),
      ),
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
          'SPENDING_LIMIT_EXCEEDED',
        ),
      ),
    );
    await bidder.rpc(
      'place_bid',
      params: {'p_auction_id': id, 'p_amount': '300.00'},
    );
    expect(await bidder.rpc('committed_in_window'), 300);
  });
}
