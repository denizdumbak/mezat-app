// Many bids on one auction at the same moment, through the real API: every
// request is its own transaction on its own database connection, which the
// pgTAP tests (one connection, one transaction) cannot do. Proves the row lock
// in place_bid: no two bids win, and the price never goes backwards.
//
// Needs `npx supabase start`. Not part of `flutter test`:
//   flutter test test_supabase --dart-define-from-file=.env
@Tags(['supabase'])
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/data/auction_repository.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

/// Kept low: local sign-ups are limited to 30 per 5 minutes for all of
/// test_supabase together.
const bidderCount = 8;

void main() {
  final run = Random().nextInt(1 << 32).toRadixString(36);
  const password = 'Passw0rd!x';

  late SupabaseClient seller;
  final bidders = <SupabaseClient>[];

  Future<SupabaseClient> signUp(String name) async {
    final client = newClient();
    await AuthRepository(
      client.auth,
    ).signUp(email: '${name}_$run@example.com', password: password);
    await ProfileRepository(
      client,
    ).setUsername(userId: client.auth.currentUser!.id, username: '${name}_$run');
    return client;
  }

  /// A live auction at ₺100 with a ₺10 minimum step.
  Future<String> liveAuction() async {
    final id = await AuctionRepository(seller).create(
      NewAuction(
        title: 'Yarış $run',
        description: 'Test',
        startPrice: const Money.kurus(10000),
        minIncrement: const Money.kurus(1000),
        durationMinutes: 30,
        startsAt: DateTime.now(),
      ),
    );
    await seller.rpc('start_auction', params: {'p_auction_id': id});
    return id;
  }

  /// place_bid's answer: 'OK' or the error code it raised.
  Future<String> bid(SupabaseClient client, String auctionId, String amount) =>
      client
          .rpc(
            'place_bid',
            params: {'p_auction_id': auctionId, 'p_amount': amount},
          )
          .then((_) => 'OK', onError: (Object e) => (e as PostgrestException).message);

  Future<Map<String, dynamic>> auctionRow(String id) => seller
      .from('auctions')
      .select('current_price::text, current_winner_id')
      .eq('id', id)
      .single();

  Future<List<Map<String, dynamic>>> bidRows(String id) => seller
      .from('bids')
      .select('bidder_id, amount::text')
      .eq('auction_id', id)
      .order('created_at', ascending: true);

  setUpAll(() async {
    seller = await signUp('seller');
    for (var i = 0; i < bidderCount; i++) {
      bidders.add(await signUp('bidder$i'));
    }
  });

  tearDownAll(() async {
    await seller.dispose();
    for (final client in bidders) {
      await client.dispose();
    }
  });

  test('the same bid from everyone at once: exactly one wins', () async {
    final id = await liveAuction();

    final answers = await Future.wait([
      for (final client in bidders) bid(client, id, '110.00'),
    ]);

    expect(answers.where((a) => a == 'OK'), hasLength(1));
    expect(answers.where((a) => a == 'BID_TOO_LOW'), hasLength(bidderCount - 1));

    final winner = bidders[answers.indexOf('OK')].auth.currentUser!.id;
    final row = await auctionRow(id);
    expect(row['current_price'], '110.00');
    expect(row['current_winner_id'], winner);

    final bids = await bidRows(id);
    expect(bids, hasLength(1));
    expect(bids.single['bidder_id'], winner);
  });

  test('different bids at once: accepted bids only ever climb', () async {
    final id = await liveAuction();
    // ₺110, ₺120, … each one minimum step apart, all sent together; the order
    // they reach the lock decides which are still high enough.
    final amounts = [
      for (var i = 1; i <= bidderCount; i++) '${100 + 10 * i}.00',
    ];

    final answers = await Future.wait([
      for (var i = 0; i < bidderCount; i++) bid(bidders[i], id, amounts[i]),
    ]);

    expect(answers, everyElement(anyOf('OK', 'BID_TOO_LOW')));
    // The highest bid cannot be too low whatever the order.
    expect(answers.last, 'OK');

    final bids = await bidRows(id);
    expect(bids, hasLength(answers.where((a) => a == 'OK').length));
    final accepted = [for (final b in bids) double.parse(b['amount'] as String)];
    for (var i = 1; i < accepted.length; i++) {
      expect(
        accepted[i],
        greaterThanOrEqualTo(accepted[i - 1] + 10),
        reason: 'each accepted bid beats the one before by the minimum step',
      );
    }

    final row = await auctionRow(id);
    expect(row['current_price'], amounts.last);
    expect(row['current_winner_id'], bidders.last.auth.currentUser!.id);
    expect(bids.last['bidder_id'], bidders.last.auth.currentUser!.id);
  });

  test('one bidder tapping twice at once is charged once', () async {
    final id = await liveAuction();

    final answers = await Future.wait([
      bid(bidders.first, id, '110.00'),
      bid(bidders.first, id, '110.00'),
    ]);

    expect(answers, unorderedEquals(['OK', anyOf('ALREADY_WINNING', 'BID_TOO_LOW')]));
    expect(await bidRows(id), hasLength(1));
  });
}
