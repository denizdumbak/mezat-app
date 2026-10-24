import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/supabase_client.dart';
import '../../core/time_format.dart';
import '../../data/spending_limit_repository.dart';
import '../auctions/feed_providers.dart';
import '../auth/session.dart';

/// Limits that protect the user from overspending (PRODUCT.md, "Güvenlik
/// katmanı"). Checked here so the button can say why it is off; place_bid
/// enforces the spending limit on the server too, since a client check alone
/// can be bypassed.
class BidSafetyConfig {
  const BidSafetyConfig({this.confirmThreshold = defaultConfirmThreshold});

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

  /// A bid of this size, or one that takes the total counted against the
  /// limit to it, needs a second confirmation.
  final Money confirmThreshold;
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

  /// The total counted against the limit if this bid wins.
  final Money committedAfter;
}

/// The bid would take the total past the spending limit. The button stays on:
/// tapping it offers to raise the limit by [overage] (PRODUCT.md).
class BidOverLimit extends BidCheck {
  const BidOverLimit({required this.overage, required this.committedAfter});

  /// How far past the limit the total would go.
  final Money overage;

  /// The total counted against the limit if this bid wins.
  final Money committedAfter;
}

/// The note under the bid button for a [BidOverLimit] bid.
String overLimitNote(SpendingLimit limit, Money overage) =>
    'Bu teklif limitini ${overage.format()} aşıyor (son '
    '${formatPeriodIn(limit.period)} en fazla ${limit.amount.format()}).';

/// Decides whether a bid of [amount] may go out, and whether it needs a
/// second confirmation.
///
/// [committed] is the total in the user's window (committed_in_window) and
/// already contains [myLeadingHere] (the user's current leading bid in this
/// auction, zero if none): a new bid in the same auction replaces it instead
/// of adding to it. A switched-off [limit] blocks nothing.
BidCheck checkBid({
  required Money amount,
  required Money committed,
  required Money myLeadingHere,
  required SpendingLimit limit,
  required Money confirmThreshold,
}) {
  final before = committed;
  final after = committed - myLeadingHere + amount;
  if (limit.enabled && after > limit.amount) {
    return BidOverLimit(overage: after - limit.amount, committedAfter: after);
  }
  final crossesThreshold =
      !(before >= confirmThreshold) && after >= confirmThreshold;
  return BidAllowed(
    needsConfirmation: amount >= confirmThreshold || crossesThreshold,
    committedAfter: after,
  );
}

/// The real table, or memory in demo mode (`MOCK_FEED`), whose users do not
/// exist on the server.
final spendingLimitRepositoryProvider = Provider<SpendingLimitRepository>(
  (ref) => useMockFeed
      ? InMemorySpendingLimitRepository()
      : SupabaseSpendingLimitRepository(ref.watch(supabaseClientProvider)),
);

final spendingLimitProvider =
    AsyncNotifierProvider<SpendingLimitNotifier, SpendingLimit>(
      SpendingLimitNotifier.new,
    );

class SpendingLimitNotifier extends AsyncNotifier<SpendingLimit> {
  /// Loaded again for each signed-in user, so switching accounts never shows
  /// the previous one's settings.
  @override
  Future<SpendingLimit> build() async {
    if (ref.watch(authUserIdProvider).value == null) {
      return SpendingLimit.defaults;
    }
    return await ref.watch(spendingLimitRepositoryProvider).load() ??
        SpendingLimit.defaults;
  }

  /// Throws [AuctionFailure] if it could not be saved; the old settings stay.
  Future<void> change(SpendingLimit limit) async {
    await ref.read(spendingLimitRepositoryProvider).save(limit);
    state = AsyncData(limit);
    // A new period counts a different stretch of time.
    ref.invalidate(committedProvider);
  }

  /// Starts the window from now. Throws [AuctionFailure] on error.
  Future<void> resetWindow() async {
    final repository = ref.read(spendingLimitRepositoryProvider);
    await repository.resetWindow();
    state = AsyncData(await repository.load() ?? SpendingLimit.defaults);
    ref.invalidate(committedProvider);
  }
}
