import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';

/// Limits that protect the user from overspending (PRODUCT.md, "Güvenlik
/// katmanı"). Client side for now; M3 enforces the daily limit in place_bid
/// too, since a client check alone can be bypassed.
class BidSafetyConfig {
  const BidSafetyConfig({
    this.confirmThreshold = defaultConfirmThreshold,
    this.defaultDailyLimit = defaultDailyLimitAmount,
  });

  /// Reads the threshold from `--dart-define=BID_CONFIRM_THRESHOLD_TRY=1500`
  /// (whole lira), falling back to ₺1.000.
  factory BidSafetyConfig.fromDefines() => BidSafetyConfig(
    confirmThreshold: Money.kurus(
      const int.fromEnvironment(
            'BID_CONFIRM_THRESHOLD_TRY',
            defaultValue: 1000,
          ) *
          100,
    ),
  );

  static const defaultConfirmThreshold = Money.kurus(100000);
  static const defaultDailyLimitAmount = Money.kurus(200000);

  /// A bid of this size, or one that takes today's total to it, needs a
  /// second confirmation.
  final Money confirmThreshold;
  final Money defaultDailyLimit;
}

final bidSafetyConfigProvider = Provider<BidSafetyConfig>(
  (ref) => BidSafetyConfig.fromDefines(),
);

sealed class BidCheck {
  const BidCheck();
}

class BidAllowed extends BidCheck {
  const BidAllowed({
    required this.needsConfirmation,
    required this.committedAfter,
  });

  final bool needsConfirmation;

  /// Today's total if this bid wins.
  final Money committedAfter;
}

class BidBlocked extends BidCheck {
  const BidBlocked(this.reason);

  final String reason;
}

/// Decides whether a bid of [amount] may go out, and whether it needs a
/// second confirmation.
///
/// [committedToday] already contains [myLeadingHere] (the user's current
/// leading bid in this auction, zero if none): a new bid in the same auction
/// replaces it instead of adding to it.
BidCheck checkBid({
  required Money amount,
  required Money committedToday,
  required Money myLeadingHere,
  required Money dailyLimit,
  required Money confirmThreshold,
}) {
  final before = committedToday;
  final after = committedToday - myLeadingHere + amount;
  if (after > dailyLimit) {
    return BidBlocked(
      'Limitine ulaştın. Günlük limitin ${dailyLimit.format()}.',
    );
  }
  final crossesThreshold =
      !(before >= confirmThreshold) && after >= confirmThreshold;
  return BidAllowed(
    needsConfirmation: amount >= confirmThreshold || crossesThreshold,
    committedAfter: after,
  );
}

/// Where the user's daily spending limit is kept. In memory for now; moves
/// to the profiles table with M3 so the server can enforce it.
abstract interface class SpendingLimitRepository {
  Future<Money?> load();
  Future<void> save(Money limit);
}

class InMemorySpendingLimitRepository implements SpendingLimitRepository {
  Money? _limit;

  @override
  Future<Money?> load() async => _limit;

  @override
  Future<void> save(Money limit) async => _limit = limit;
}

final spendingLimitRepositoryProvider = Provider<SpendingLimitRepository>(
  (ref) => InMemorySpendingLimitRepository(),
);

final dailyLimitProvider = AsyncNotifierProvider<DailyLimitNotifier, Money>(
  DailyLimitNotifier.new,
);

class DailyLimitNotifier extends AsyncNotifier<Money> {
  @override
  Future<Money> build() async =>
      await ref.watch(spendingLimitRepositoryProvider).load() ??
      ref.watch(bidSafetyConfigProvider).defaultDailyLimit;

  Future<void> change(Money limit) async {
    await ref.read(spendingLimitRepositoryProvider).save(limit);
    state = AsyncData(limit);
  }
}
