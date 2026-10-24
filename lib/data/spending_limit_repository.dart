import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/money.dart';
import 'supabase_errors.dart';

/// The user's spending-control settings (PRODUCT.md, "Güvenlik katmanı"):
/// at most [amount] in the last [period], unless they switched it off.
class SpendingLimit {
  const SpendingLimit({
    required this.amount,
    required this.period,
    required this.enabled,
    this.resetAt,
  });

  /// What applies to a user who never changed it; same as place_bid's
  /// default for users without a spending_limits row.
  static const defaults = SpendingLimit(
    amount: Money.kurus(200000),
    period: Duration(days: 1),
    enabled: true,
  );

  /// The choices offered next to "Özel": 6 hours, 1 day, 1 week, 1 month.
  static const presetPeriods = [
    Duration(hours: 6),
    Duration(days: 1),
    Duration(days: 7),
    Duration(days: 30),
  ];

  /// The range the server accepts for a custom period.
  static const minPeriod = Duration(hours: 1);
  static const maxPeriod = Duration(days: 365);

  final Money amount;
  final Duration period;
  final bool enabled;

  /// When the user last reset the window; auctions won before it no longer
  /// count. Null if never.
  final DateTime? resetAt;

  SpendingLimit copyWith({Money? amount, Duration? period, bool? enabled}) =>
      SpendingLimit(
        amount: amount ?? this.amount,
        period: period ?? this.period,
        enabled: enabled ?? this.enabled,
        resetAt: resetAt,
      );

  @override
  bool operator ==(Object other) =>
      other is SpendingLimit &&
      other.amount == amount &&
      other.period == period &&
      other.enabled == enabled &&
      other.resetAt == resetAt;

  @override
  int get hashCode => Object.hash(amount, period, enabled, resetAt);
}

/// Where the signed-in user's spending limit is kept.
///
/// Every method throws [AuctionFailure] on error.
abstract interface class SpendingLimitRepository {
  /// The user's own settings, or null if they never changed them (the
  /// defaults apply).
  Future<SpendingLimit?> load();

  Future<void> save(SpendingLimit limit);

  /// Starts counting from now: auctions won before no longer count.
  Future<void> resetWindow();
}

/// The `spending_limits` table. RLS shows a user only their own row, and
/// `user_id` defaults to the caller, so no method names the user.
/// `place_bid` enforces the same settings on the server.
class SupabaseSpendingLimitRepository implements SpendingLimitRepository {
  SupabaseSpendingLimitRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<SpendingLimit?> load() => guardAuctions(() async {
    final row = await _client
        .from('spending_limits')
        .select('limit_amount::text, period::text, enabled, reset_at')
        .maybeSingle();
    if (row == null) return null;
    final resetAt = row['reset_at'] as String?;
    return SpendingLimit(
      amount: Money.parseDb(row['limit_amount'] as String),
      period: parsePgInterval(row['period'] as String),
      enabled: row['enabled'] as bool,
      resetAt: resetAt == null ? null : DateTime.parse(resetAt),
    );
  });

  @override
  Future<void> save(SpendingLimit limit) => guardAuctions(
    () => _client.from('spending_limits').upsert({
      'limit_amount': limit.amount.toDb(),
      // Always whole hours; Postgres reads "168 hours" as a week.
      'period': '${limit.period.inHours} hours',
      'enabled': limit.enabled,
    }, onConflict: 'user_id'),
  );

  @override
  Future<void> resetWindow() =>
      guardAuctions(() => _client.rpc('reset_spending_window'));
}

/// Reads Postgres' default interval output for the periods the app writes:
/// "1 day", "7 days", "06:00:00", "36:00:00", "2 days 03:00:00".
Duration parsePgInterval(String raw) {
  final match = RegExp(
    r'^(?:(\d+) days?)?\s*(?:(\d+):(\d{2}):(\d{2}))?$',
  ).firstMatch(raw.trim());
  if (match == null || raw.trim().isEmpty) {
    throw FormatException('Unexpected interval', raw);
  }
  int part(int group) => int.parse(match.group(group) ?? '0');
  return Duration(
    days: part(1),
    hours: part(2),
    minutes: part(3),
    seconds: part(4),
  );
}

/// Kept in memory: demo mode and tests.
class InMemorySpendingLimitRepository implements SpendingLimitRepository {
  InMemorySpendingLimitRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  SpendingLimit? _limit;

  @override
  Future<SpendingLimit?> load() async => _limit;

  @override
  Future<void> save(SpendingLimit limit) async => _limit = SpendingLimit(
    amount: limit.amount,
    period: limit.period,
    enabled: limit.enabled,
    resetAt: _limit?.resetAt,
  );

  @override
  Future<void> resetWindow() async {
    final current = _limit ?? SpendingLimit.defaults;
    _limit = SpendingLimit(
      amount: current.amount,
      period: current.period,
      enabled: current.enabled,
      resetAt: _clock(),
    );
  }
}
