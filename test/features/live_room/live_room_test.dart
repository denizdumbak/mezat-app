import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/auction_failure.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/widgets/price_display.dart';
import 'package:mezat_app/core/widgets/states.dart';
import 'package:mezat_app/data/auction_feed_repository.dart';
import 'package:mezat_app/data/spending_limit_repository.dart';

import '../../helpers/fakes.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/screens.dart';

final _bidButton = find.byWidgetPredicate(
  (w) =>
      w is FilledButton &&
      w.child is Text &&
      (w.child! as Text).data!.endsWith('teklif ver'),
);

FilledButton _button(WidgetTester tester) =>
    tester.widget<FilledButton>(_bidButton);

/// A cheap auction: +₺10 on ₺500 stays far from every threshold.
LiveRoom _cheapRoom({List<Bid>? bids}) =>
    liveRoom(price: const Money.kurus(50000), bids: bids);

void main() {
  testWidgets('long seller name and a 6-digit price fit a small phone', (
    tester,
  ) async {
    useSmallPhone(tester);
    await openRoom(
      tester,
      liveRoom(
        seller: longUsername,
        price: sixDigits,
        bids: [bid('b1', longUsername, 999999)],
      ),
    );

    expect(find.text('@$longUsername'), findsWidgets);
    expect(
      tester.widget<PriceDisplay>(find.byType(PriceDisplay)).amount,
      sixDigits,
    );
    expect(find.text('₺999.999'), findsOneWidget); // the feed row
    expect(tester.takeException(), isNull);
  });

  testWidgets('the smallest increment is selected and bids current + it', (
    tester,
  ) async {
    useSmallPhone(tester);
    final feed = await openRoom(tester, _cheapRoom());

    expect(find.text('+₺10 teklif ver'), findsOneWidget);
    expect(
      find.text('Artış ₺10 · Son 30 sn’de teklif +30 sn uzatır'),
      findsOneWidget,
    );
    await tapVisible(tester, _bidButton);

    expect(feed.placed.single.amount, const Money.kurus(51000));
  });

  testWidgets('choosing another chip changes the bid', (tester) async {
    useSmallPhone(tester);
    final feed = await openRoom(tester, _cheapRoom());

    await tapVisible(tester, find.text('+₺50'));
    expect(find.text('+₺50 teklif ver'), findsOneWidget);
    await tapVisible(tester, _bidButton);

    expect(feed.placed.single.amount, const Money.kurus(55000));
  });

  group('high bid confirmation', () {
    testWidgets('a bid of ₺1.000 or more asks first; Vazgeç sends nothing', (
      tester,
    ) async {
      useSmallPhone(tester);
      final feed = await openRoom(tester, liveRoom());

      await tapVisible(tester, _bidButton);
      expect(find.text('Yüksek tutarlı teklif'), findsOneWidget);
      expect(find.text('₺1.260 teklif vermek üzeresin.'), findsOneWidget);

      await tapVisible(tester, find.text('Vazgeç'));
      expect(feed.placed, isEmpty);
    });

    testWidgets('confirming sends the bid', (tester) async {
      useSmallPhone(tester);
      final feed = await openRoom(tester, liveRoom());

      await tapVisible(tester, _bidButton);
      await tapVisible(tester, find.text('Onaylıyorum'));

      expect(feed.placed.single.amount, const Money.kurus(126000));
    });

    testWidgets('a small bid that takes today over ₺1.000 asks too', (
      tester,
    ) async {
      useSmallPhone(tester);
      await openRoom(tester, _cheapRoom(), committed: const Money.kurus(95000));

      await tapVisible(tester, _bidButton);
      expect(
        find.text('Kazanırsan limitine sayılan toplam ₺1.460 olur.'),
        findsOneWidget,
      );
    });
  });

  group('over the spending limit', () {
    // ₺1.950 counted + ₺1.260 bid = ₺3.210: ₺1.210 past the ₺2.000 limit.
    Future<FakeAuctionFeedRepository> openOverLimit(
      WidgetTester tester,
      InMemorySpendingLimitRepository limits,
    ) async {
      useSmallPhone(tester);
      return openRoom(
        tester,
        liveRoom(),
        committed: const Money.kurus(195000),
        spendingLimit: limits,
      );
    }

    testWidgets('the button stays on, a note says by how much; Kapat sends '
        'nothing', (tester) async {
      final feed = await openOverLimit(
        tester,
        InMemorySpendingLimitRepository(),
      );

      expect(_button(tester).onPressed, isNotNull);
      expect(
        find.text(
          'Bu teklif limitini ₺1.210 aşıyor (son 1 günde en fazla ₺2.000).',
        ),
        findsOneWidget,
      );
      await tapVisible(tester, _bidButton);
      expect(find.text('Limit aşıldı'), findsOneWidget);
      await tapVisible(tester, find.text('Kapat'));
      expect(feed.placed, isEmpty);
    });

    testWidgets('Limiti artır asks first; Hayır changes nothing', (
      tester,
    ) async {
      final limits = InMemorySpendingLimitRepository();
      final feed = await openOverLimit(tester, limits);

      await tapVisible(tester, _bidButton);
      await tapVisible(tester, find.text('Limiti artır'));
      expect(
        find.text(
          "Limitin ₺2.000'den ₺3.210'a çıkacak ve ₺1.260 pey verilecek. "
          'Emin misin?',
        ),
        findsOneWidget,
      );
      await tapVisible(tester, find.text('Hayır'));

      expect(feed.placed, isEmpty);
      expect(await limits.load(), isNull);
    });

    testWidgets('Evet raises the limit by the overage and sends the bid', (
      tester,
    ) async {
      final limits = InMemorySpendingLimitRepository();
      final feed = await openOverLimit(tester, limits);

      await tapVisible(tester, _bidButton);
      await tapVisible(tester, find.text('Limiti artır'));
      await tapVisible(tester, find.text('Evet'));

      expect((await limits.load())!.amount, const Money.kurus(321000));
      // No separate high-bid confirmation: the last sheet named the amount.
      expect(find.text('Yüksek tutarlı teklif'), findsNothing);
      expect(feed.placed.single.amount, const Money.kurus(126000));
    });

    testWidgets('a server refusal over the limit opens the same sheet', (
      tester,
    ) async {
      useSmallPhone(tester);
      final feed = await openRoom(tester, _cheapRoom())
        ..nextBidError = AuctionFailure.spendingLimitExceeded;
      // The server knows of more than this screen (won on another device).
      feed.committed = const Money.kurus(195000);

      await tapVisible(tester, _bidButton);

      expect(find.text('Limit aşıldı'), findsOneWidget);
      expect(
        find.text('Bu teklif harcama limitini ₺460 aşıyor.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('the leader cannot bid again and is told why', (tester) async {
    useSmallPhone(tester);
    await openRoom(
      tester,
      _cheapRoom(bids: [bid('b1', 'deniz', 500, bidderId: me)]),
    );

    expect(_button(tester).onPressed, isNull);
    expect(
      find.text('Biri geçerse yeniden teklif verebilirsin.'),
      findsOneWidget,
    );
  });

  testWidgets('a seller cannot bid on their own auction', (tester) async {
    useSmallPhone(tester);
    await openRoom(tester, liveRoom(sellerId: me, seller: 'deniz'));

    expect(_button(tester).onPressed, isNull);
    expect(find.text('Kendi mezatına teklif veremezsin.'), findsOneWidget);
  });

  testWidgets('when the connection drops, bidding pauses and says so', (
    tester,
  ) async {
    useSmallPhone(tester);
    final feed = await openRoom(tester, _cheapRoom());

    feed
      ..rooms['canon'] = liveRoom(
        price: const Money.kurus(50000),
        connected: false,
      )
      ..emit();
    await tester.pumpAndSettle();

    expect(find.text(ConnectionBanner.text), findsOneWidget);
    expect(find.text('Bağlantı bekleniyor.'), findsOneWidget);
    expect(_button(tester).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refused bid explains why', (tester) async {
    useSmallPhone(tester);
    final feed = await openRoom(tester, _cheapRoom())
      ..nextBidError = AuctionFailure.bidTooLow;

    await tapVisible(tester, _bidButton);

    expect(find.text(AuctionFailure.bidTooLow.message), findsOneWidget);
    expect(feed.placed, isEmpty);
  });

  testWidgets('a second tap while a bid is on its way is ignored', (
    tester,
  ) async {
    useSmallPhone(tester);
    final feed = await openRoom(tester, _cheapRoom())
      ..bidGate = Completer<void>();

    await tester.ensureVisible(_bidButton);
    await tester.tap(_bidButton);
    await tester.pump();
    // Now showing the loader instead of its label.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);

    feed.bidGate!.complete();
    await tester.pumpAndSettle();
    expect(feed.placed, hasLength(1));
  });

  testWidgets('with no bids yet it invites the first one', (tester) async {
    useSmallPhone(tester);
    await openRoom(tester, _cheapRoom(bids: const []));

    expect(find.text('İlk teklifi sen ver'), findsOneWidget);
  });

  testWidgets('your leading bid shows as "Sen" and "Öndesin"', (tester) async {
    useSmallPhone(tester);
    await openRoom(
      tester,
      _cheapRoom(bids: [bid('b1', 'deniz', 500, bidderId: me)]),
    );

    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Öndesin'), findsOneWidget);
  });

  group('the end', () {
    testWidgets('sold: stamp, winner and a firm haptic', (tester) async {
      useSmallPhone(tester);
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final feed = await openRoom(tester, _cheapRoom());

      feed
        ..rooms['canon'] = liveRoom(
          ended: true,
          sold: const SoldResult(
            winnerId: 'bot-$longUsername',
            winnerUsername: longUsername,
            amount: sixDigits,
          ),
        )
        ..emit();
      await tester.pumpAndSettle();

      expect(find.text('SATILDI'), findsOneWidget);
      expect(find.text('@$longUsername'), findsOneWidget);
      expect(find.text('₺999.999 ile kazandı.'), findsOneWidget);
      expect(haptics, ['HapticFeedbackType.heavyImpact']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('when you win it says "Kazandın"', (tester) async {
      useSmallPhone(tester);
      await openRoom(
        tester,
        liveRoom(
          ended: true,
          sold: const SoldResult(
            winnerId: me,
            winnerUsername: 'deniz',
            amount: Money.kurus(126000),
          ),
        ),
      );

      expect(find.text('Kazandın'), findsOneWidget);
      expect(find.text('₺1.260 ile senin oldu.'), findsOneWidget);
    });

    testWidgets('no bids: time is up, nothing sold', (tester) async {
      useSmallPhone(tester);
      await openRoom(tester, liveRoom(ended: true, bids: const []));

      expect(find.text('Süre doldu'), findsOneWidget);
      expect(find.text('SATILDI'), findsNothing);
    });
  });

  testWidgets('a room that does not exist shows an error', (tester) async {
    useSmallPhone(tester);
    final feed = FakeAuctionFeedRepository()
      ..discover = [liveAuction(id: 'gone', title: 'Kaldırılmış mezat')];
    await pumpSignedIn(tester, feed: feed);
    await tester.tap(find.text('Kaldırılmış mezat'));
    await tester.pumpAndSettle();

    expect(find.text(AuctionFailure.notFound.message), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
}
