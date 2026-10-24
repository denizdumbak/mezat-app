import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/widgets/price_label.dart';
import 'package:mezat_app/features/auctions/widgets/auction_card.dart';
import 'package:mezat_app/features/auctions/widgets/auction_visuals.dart';

import '../../helpers/sample_data.dart';
import '../../helpers/themed.dart';

const _longTitle =
    'Çok uzun başlıklı bir ürün: el yapımı, gümüş kaplama, antika '
    'İstanbul işi kahve takımı ve tepsisi';

String _plain(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).textSpan!.toPlainText();

void main() {
  group('PriceLabel', () {
    testWidgets('Turkish separators, kuruş, a smaller lira sign', (
      tester,
    ) async {
      await pumpThemed(tester, const PriceLabel(Money.kurus(125050)));
      final text = find.byType(Text);
      expect(_plain(tester, text), '₺1.250,50');

      final spans = (tester.widget<Text>(text).textSpan! as TextSpan).children!;
      final sign = (spans.first as TextSpan).style!.fontSize!;
      final digits = (spans.last as TextSpan).style!.fontSize!;
      expect(sign, lessThan(digits));
      expect(sign, digits * PriceLabel.signScale);
    });

    testWidgets('with a prefix, read as one phrase', (tester) async {
      await pumpThemed(
        tester,
        const PriceLabel(Money.kurus(65000), prefix: 'Açılış'),
      );
      expect(_plain(tester, find.byType(Text)), 'Açılış ₺650');
      expect(find.bySemanticsLabel('Açılış ₺650'), findsOneWidget);
    });
  });

  group('AuctionCard', () {
    testWidgets('live: photo, "CANLI · 236", time left, seller, title, bid', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        // pumpThemed stretches its child; the strip gives a card 168 dp.
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 168,
            child: AuctionCard.live(auction: liveAuction()),
          ),
        ),
      );

      expect(find.text('CANLI · 236'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^0[34]:\d\d$')), findsOneWidget);
      expect(find.text('@analogdukkan'), findsOneWidget);
      expect(find.text('Canon AE-1 Program, 50mm f/1.8 lens'), findsOneWidget);
      expect(_plain(tester, find.byType(Text).last), '₺1.250');
      final photo = tester.widget<AuctionPhoto>(find.byType(AuctionPhoto));
      expect(photo.aspectRatio, 3 / 4);
      expect(photo.imageUrl, 'assets/mock/canon-ae1.jpg');
    });

    testWidgets('live: long seller, long title and 6 digits fit 168 dp', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 168,
            child: AuctionCard.live(
              auction: liveAuction(
                seller: longUsername,
                title: _longTitle,
                price: sixDigits,
                viewers: 12400,
              ),
            ),
          ),
        ),
        width: 360,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('CANLI · 12 B'), findsOneWidget);
    });

    testWidgets('upcoming: start time on the photo and a reminder button', (
      tester,
    ) async {
      var reminded = false;
      await pumpThemed(
        tester,
        AuctionCard.upcoming(
          auction: upcomingAuction(startsIn: const Duration(minutes: 30)),
          onRemind: () => reminded = true,
        ),
      );

      expect(find.textContaining('Bugün '), findsOneWidget);
      expect(find.text('@kasetcafe'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == 'Açılış ₺350',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Hatırlat'));
      expect(reminded, isTrue);
    });

    testWidgets('ended: faded, "Satıldı ₺1.600"', (tester) async {
      await pumpThemed(tester, AuctionCard.ended(auction: endedAuction()));

      expect(find.text('Satıldı'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == 'Satıldı ₺1.600',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        AuctionCard.endedOpacity,
      );
      expect(find.byTooltip('Hatırlat'), findsNothing);
    });

    testWidgets('row: thumbnail with the live badge, details, trailing', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        AuctionCard.row(
          auction: liveAuction(seller: longUsername, price: sixDigits),
          trailing: const Icon(Icons.chevron_right),
        ),
        width: 360,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LiveBadge), findsOneWidget);
      expect(find.text('@$longUsername'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('row of an upcoming auction: when, and the opening price', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        AuctionCard.row(auction: upcomingAuction()),
        width: 360,
      );
      expect(find.byType(LiveBadge), findsNothing);
      expect(find.textContaining(RegExp(r'^(Bugün|Yarın) ')), findsOneWidget);
    });
  });

  group('AuctionPhoto placeholder', () {
    testWidgets('no photo: the first letter of the title, no grey icon', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        AuctionCard.upcoming(auction: upcomingAuction(imageUrl: null)),
      );
      expect(find.byKey(const Key('auctionPhoto.placeholder')), findsOneWidget);
      expect(find.text('S'), findsOneWidget);
      expect(find.byIcon(Icons.photo_outlined), findsNothing);
    });

    testWidgets('a bundled photo that is missing falls back the same way', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        AuctionCard.upcoming(
          auction: upcomingAuction(imageUrl: 'assets/mock/yok.jpg'),
        ),
      );
      // Loading an asset is real I/O: let it fail outside the fake clock.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.byKey(const Key('auctionPhoto.placeholder')), findsOneWidget);
    });
  });
}
