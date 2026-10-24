import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';
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
  int threshold = 1000,
}) => checkBid(
  amount: tl(amount),
  committedToday: tl(committed),
  myLeadingHere: tl(myLeadingHere),
  dailyLimit: tl(limit),
  confirmThreshold: tl(threshold),
);

void main() {
  test('defaults: ₺1.000 confirmation, ₺2.000 daily limit', () {
    const config = BidSafetyConfig();
    expect(config.confirmThreshold, tl(1000));
    expect(config.defaultDailyLimit, tl(2000));
    // Without --dart-define the build uses the same threshold.
    expect(BidSafetyConfig.fromDefines().confirmThreshold, tl(1000));
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
  });

  group('daily limit', () {
    test('a bid that would pass the limit is blocked, with the reason', () {
      final result = check(amount: 1260, committed: 900);
      expect(result, isA<BidBlocked>());
      expect(
        (result as BidBlocked).reason,
        'Limitine ulaştın. Günlük limitin ₺2.000.',
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
  });

  test('the daily limit can be changed and is kept', () async {
    final repository = InMemorySpendingLimitRepository();
    expect(await repository.load(), isNull);
    await repository.save(tl(5000));
    expect(await repository.load(), tl(5000));
  });

  test('each account sees its own limit, not the previous one\'s', () async {
    final auth = FakeAuthRepository(signedInAs: 'user-0');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        spendingLimitRepositoryProvider.overrideWithValue(
          _PerUserLimits(auth, {'user-0': tl(7000)}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(dailyLimitProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(dailyLimitProvider.future), tl(7000));

    await auth.signOut();
    await auth.signIn(email: 'other@example.com', password: 'x');
    await Future<void>.delayed(Duration.zero);

    // user-1 never set one: the default, not user-0's ₺7.000.
    expect(await container.read(dailyLimitProvider.future), tl(2000));
  });
}

/// Answers with the limit of whoever is signed in, like the RLS-filtered table.
class _PerUserLimits implements SpendingLimitRepository {
  _PerUserLimits(this.auth, this.limits);

  final FakeAuthRepository auth;
  final Map<String, Money> limits;

  @override
  Future<Money?> load() async => limits[auth.currentUserId];

  @override
  Future<void> save(Money limit) async => limits[auth.currentUserId!] = limit;
}
