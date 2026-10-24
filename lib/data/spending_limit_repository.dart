import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import 'supabase_errors.dart';

/// Where the signed-in user's daily spending limit is kept.
///
/// Every method throws [AuctionFailure] on error.
abstract interface class SpendingLimitRepository {
  /// The user's own limit, or null if they never set one (the default
  /// applies).
  Future<Money?> load();

  Future<void> save(Money limit);
}

/// The `spending_limits` table. RLS shows a user only their own row, and
/// `user_id` defaults to the caller, so neither method names the user.
/// `place_bid` enforces the same limit on the server.
class SupabaseSpendingLimitRepository implements SpendingLimitRepository {
  SupabaseSpendingLimitRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Money?> load() => guardAuctions(() async {
    final row = await _client
        .from('spending_limits')
        .select('limit_amount::text')
        .maybeSingle();
    return row == null ? null : Money.parseDb(row['limit_amount'] as String);
  });

  @override
  Future<void> save(Money limit) => guardAuctions(
    () => _client
        .from('spending_limits')
        .upsert({'limit_amount': limit.toDb()}, onConflict: 'user_id'),
  );
}

/// Kept in memory: demo mode and tests.
class InMemorySpendingLimitRepository implements SpendingLimitRepository {
  Money? _limit;

  @override
  Future<Money?> load() async => _limit;

  @override
  Future<void> save(Money limit) async => _limit = limit;
}
