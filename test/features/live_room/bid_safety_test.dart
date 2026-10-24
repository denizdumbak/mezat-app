import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/time_format.dart';
import 'package:mezat_app/data/auth_repository.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';
import 'package:mezat_app/features/live_room/bid_safety.dart';

import '../../helpers/fakes.dart';

Money tl(int lira) => Money.kurus(lira * 100);

BidCheck check({
  required int amount,
  int committed = 0,
  int myLeadingHere = 0,
  int limit = 2000,
  Duration period = const Duration(days: 1),
  bool enabled = true,
  int threshold = 1000,
}) => checkBid(
  amount: tl(amount),
  committed: tl(committed),
  myLeadingHere: tl(myLeadingHere),
  limit: SpendingLimit(amount: tl(limit), period: period, enabled: enabled),
  confirmThreshold: tl(threshold),
);

void main() {
  test('defaults: ₺1.000 confirmation; limit on, ₺2.000 in 1 day', () {
    expect(const BidSafetyConfig().confirmThreshold, tl(1000));
    // Without --dart-define the build uses the same threshold.
    expect(BidSafetyConfig.fromDefines().confirmThreshold, tl(1000));
    expect(SpendingLimit.defaults.amount, tl(2000));
    expect(SpendingLimit.defaults.period, const Duration(days: 1));
    expect(SpendingLimit.defaults.enabled, isTrue);
  });

  group('confirmation', () {
    test('a small bid with a small total goes straight out', () {
      final result = check(amount: 510) as BidAllowed;
      expect(result.needsConfirmation, isFalse);
      expect(result.committedAfter, tl(510));
    });

    test('a single bid at the threshold needs confirmation', () {
      expect((check(amount: 1000) as BidAllowed).needsConfirmation, isTrue);
      expect((check(amount: 999) as BidAllowed).needsConfirmation, isFalse);
    });

    test('a bid that takes the total over the threshold needs it', () {
      final result = check(amount: 60, committed: 950) as BidAllowed;
      expect(result.needsConfirmation, isTrue);
      expect(result.committedAfter, tl(1010));
    });

    test('once over the threshold, small bids do not ask every time', () {
      final result = check(amount: 60, committed: 1200) as BidAllowed;
      expect(result.needsConfirmation, isFalse);
    });

    test('a switched-off limit still asks for high bids', () {
      final result = check(amount: 5000, enabled: false) as BidAllowed;
      expect(result.needsConfirmation, isTrue);
    });
  });

  group('spending limit', () {
    test('a bid that would pass the limit is blocked, with the reason', () {
      final result = check(amount: 1260, committed: 900);
      expect(result, isA<BidBlocked>());
      expect(
        (result as BidBlocked).reason,
        'Limitine ulaştın. Son 1 günde en fazla ₺2.000.',
      );
    });

    test('the reason names the chosen period', () {
      final result = check(
        amount: 1260,
        committed: 900,
        period: const Duration(hours: 6),
      );
      expect(
        (result as BidBlocked).reason,
        'Limitine ulaştın. Son 6 saatte en fazla ₺2.000.',
      );
    });

    test('exactly reaching the limit is allowed', () {
      expect(check(amount: 1100, committed: 900), isA<BidAllowed>());
    });

    test('raising your own leading bid replaces it, not adds to it', () {
      // Leading here with ₺1.500 of ₺1.500 committed; ₺1.550 is a raise of
      // ₺50, well inside ₺2.000.
      final result =
          check(amount: 1550, committed: 1500, myLeadingHere: 1500)
              as BidAllowed;
      expect(result.committedAfter, tl(1550));
    });

    test('a higher personal limit lets the same bid through', () {
      expect(
        check(amount: 1260, committed: 900, limit: 5000),
        isA<BidAllowed>(),
      );
    });

    test('a switched-off limit blocks nothing', () {
      expect(
        check(amount: 99999, committed: 900, enabled: false),
        isA<BidAllowed>(),
      );
    });
  });

  group('periods', () {
    test('are named in their largest whole unit', () {
      expect(formatPeriod(const Duration(hours: 6)), '6 saat');
      expect(formatPeriod(const Duration(hours: 36)), '36 saat');
      expect(formatPeriod(const Duration(days: 1)), '1 gün');
      expect(formatPeriod(const Duration(days: 3)), '3 gün');
      expect(formatPeriod(const Duration(days: 7)), '1 hafta');
      expect(formatPeriod(const Duration(days: 14)), '2 hafta');
      expect(formatPeriod(const Duration(days: 30)), '1 ay');
      expect(formatPeriod(const Duration(days: 365)), '365 gün');
    });

    test('take the locative ending after "Son"', () {
      expect(formatPeriodIn(const Duration(hours: 6)), '6 saatte');
      expect(formatPeriodIn(const Duration(days: 1)), '1 günde');
      expect(formatPeriodIn(const Duration(days: 7)), '1 haftada');
      expect(formatPeriodIn(const Duration(days: 30)), '1 ayda');
    });

    test('are read from Postgres interval text', () {
      expect(parsePgInterval('1 day'), const Duration(days: 1));
      expect(parsePgInterval('7 days'), const Duration(days: 7));
      expect(parsePgInterval('06:00:00'), const Duration(hours: 6));
      expect(parsePgInterval('36:00:00'), const Duration(hours: 36));
      expect(parsePgInterval('168:00:00'), const Duration(days: 7));
      expect(
        parsePgInterval('2 days 03:00:00'),
        const Duration(days: 2, hours: 3),
      );
      expect(() => parsePgInterval('1 mon'), throwsFormatException);
    });
  });

  group('the in-memory store', () {
    test('keeps the settings and a reset time', () async {
      final now = DateTime(2026, 10, 24, 15);
      final repository = InMemorySpendingLimitRepository(clock: () => now);
      expect(await repository.load(), isNull);

      final mine = SpendingLimit(
        amount: tl(5000),
        period: const Duration(hours: 6),
        enabled: true,
      );
      await repository.save(mine);
      expect(await repository.load(), mine);

      await repository.resetWindow();
      final reset = (await repository.load())!;
      expect(reset.resetAt, now);
      expect(reset.amount, tl(5000));

      // Saving new settings keeps the reset.
      await repository.save(mine.copyWith(enabled: false));
      expect((await repository.load())!.resetAt, now);
    });
  });

  test('each account sees its own limit, not the previous one\'s', () async {
    final auth = FakeAuthRepository(signedInAs: 'user-0');
    final mine = SpendingLimit(
      amount: tl(7000),
      period: const Duration(days: 7),
      enabled: true,
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        spendingLimitRepositoryProvider.overrideWithValue(
          _PerUserLimits(auth, {'user-0': mine}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(spendingLimitProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(spendingLimitProvider.future), mine);

    await auth.signOut();
    await auth.signIn(email: 'other@example.com', password: 'x');
    await Future<void>.delayed(Duration.zero);

    // user-1 never changed theirs: the defaults, not user-0's settings.
    expect(
      await container.read(spendingLimitProvider.future),
      SpendingLimit.defaults,
    );
  });
}

/// Answers with the settings of whoever is signed in, like the RLS-filtered
/// table.
class _PerUserLimits implements SpendingLimitRepository {
  _PerUserLimits(this.auth, this.limits);

  final FakeAuthRepository auth;
  final Map<String, SpendingLimit> limits;

  @override
  Future<SpendingLimit?> load() async => limits[auth.currentUserId];

  @override
  Future<void> save(SpendingLimit limit) async =>
      limits[auth.currentUserId!] = limit;

  @override
  Future<void> resetWindow() async {}
}
