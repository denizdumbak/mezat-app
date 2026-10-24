import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/design_tokens.dart';
import 'package:mezat_app/app/theme.dart';
import 'package:mezat_app/core/auction_rules.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/widgets/app_loader.dart';
import 'package:mezat_app/core/widgets/bid_feed_row.dart';
import 'package:mezat_app/core/widgets/countdown.dart';
import 'package:mezat_app/core/widgets/increment_chip.dart';
import 'package:mezat_app/core/widgets/price_display.dart';
import 'package:mezat_app/core/widgets/primary_button.dart';
import 'package:mezat_app/core/widgets/states.dart';

import '../helpers/themed.dart';

/// Widgets of type [inner] inside [outer], ignoring the page route's own
/// transitions and text styles.
Finder _inside(Type outer, Type inner) =>
    find.descendant(of: find.byType(outer), matching: find.byType(inner));

void main() {
  group('PrimaryButton', () {
    testWidgets('is at least 48 dp, the bid variant 56 dp', (tester) async {
      await pumpThemed(
        tester,
        Column(
          children: [
            PrimaryButton(label: 'Devam et', onPressed: () {}),
            PrimaryButton.bid(label: '+₺10 teklif ver', onPressed: () {}),
          ],
        ),
      );

      final sizes = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .map((b) => tester.getSize(find.byWidget(b)).height)
          .toList();
      expect(sizes, [AppSize.touch, AppSize.bidButton]);
    });

    testWidgets('busy shows the loader and ignores taps', (tester) async {
      var taps = 0;
      await pumpThemed(
        tester,
        PrimaryButton(label: 'Devam et', onPressed: () => taps++, busy: true),
      );

      expect(find.byType(AppLoader), findsOneWidget);
      expect(find.text('Devam et'), findsNothing);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  group('SecondaryButton', () {
    Color? fill(WidgetTester tester) => tester
        .widget<FilledButton>(find.byType(FilledButton))
        .style!
        .backgroundColor!
        .resolve({});

    for (final (name, theme) in [
      ('browse', browseTheme),
      ('live room', liveTheme),
    ]) {
      testWidgets('is a 48 dp pill one tone lighter, in the $name theme', (
        tester,
      ) async {
        var taps = 0;
        await pumpThemed(
          tester,
          SecondaryButton(label: 'Hayır', onPressed: () => taps++),
          theme: theme,
        );

        final palette = theme.extension<AppPalette>()!;
        expect(fill(tester), palette.secondaryFill);
        expect(fill(tester), isNot(theme.colorScheme.primary));
        expect(fill(tester), isNot(theme.colorScheme.surface));
        expect(tester.getSize(find.byType(FilledButton)).height, AppSize.touch);
        await tester.tap(find.text('Hayır'));
        expect(taps, 1);
      });
    }
  });

  testWidgets('IncrementChip shows "+₺50" and reports taps', (tester) async {
    var selected = false;
    await pumpThemed(
      tester,
      IncrementChip(
        increment: const Money.kurus(5000),
        selected: false,
        onSelected: () => selected = true,
      ),
    );

    expect(find.text('+₺50'), findsOneWidget);
    expect(
      tester.getSize(find.byType(IncrementChip)).height,
      greaterThanOrEqualTo(AppSize.touch),
    );
    await tester.tap(find.byType(IncrementChip));
    expect(selected, isTrue);
  });

  group('PriceDisplay', () {
    testWidgets('rolls the changed digits up, then settles', (tester) async {
      Widget price(int kurus) => PriceDisplay(amount: Money.kurus(kurus));
      await pumpThemed(tester, price(125000));
      expect(find.bySemanticsLabel('₺1.250'), findsOneWidget);

      await pumpThemed(tester, price(126000));
      await tester.pump(AppDurations.price ~/ 2);
      // Mid-change both the old and the new "5"/"6" are on screen.
      expect(find.text('5'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(_inside(PriceDisplay, SlideTransition), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('5'), findsNothing);
      expect(find.bySemanticsLabel('₺1.260'), findsOneWidget);
    });

    testWidgets('with reduced motion it only fades', (tester) async {
      Widget price(int kurus) => PriceDisplay(amount: Money.kurus(kurus));
      await pumpThemed(tester, price(125000), reduceMotion: true);
      await pumpThemed(tester, price(126000), reduceMotion: true);
      await tester.pump(AppDurations.price ~/ 2);

      expect(_inside(PriceDisplay, SlideTransition), findsNothing);
      expect(_inside(PriceDisplay, FadeTransition), findsWidgets);
    });

    testWidgets('a 6-digit amount fits a phone screen', (tester) async {
      await pumpThemed(
        tester,
        const PriceDisplay(amount: Money.kurus(99999900)),
        width: 360,
      );
      expect(find.bySemanticsLabel('₺999.999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Countdown', () {
    final start = DateTime(2026, 10, 24, 12);

    testWidgets('counts down every second', (tester) async {
      var now = start;
      await pumpThemed(
        tester,
        Countdown(
          endsAt: start.add(const Duration(minutes: 4, seconds: 10)),
          clock: () => now,
        ),
      );
      expect(find.text('04:10'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('04:09'), findsOneWidget);
    });

    testWidgets('turns live red for the anti-sniping window', (tester) async {
      var now = start;
      Color colour() => tester
          .widget<AnimatedDefaultTextStyle>(
            _inside(Countdown, AnimatedDefaultTextStyle),
          )
          .style
          .color!;
      await pumpThemed(
        tester,
        Countdown(
          endsAt: start.add(antiSnipingWindow + const Duration(seconds: 1)),
          clock: () => now,
        ),
        theme: liveTheme,
      );
      // The live room's text colour, not black: the style is merged onto the
      // theme's.
      expect(colour(), AppColors.liveText);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:30'), findsOneWidget);
      expect(colour(), AppColors.live);
    });

    test('the red window is the anti-sniping window', () {
      expect(Countdown(endsAt: DateTime(2026)).urgentBelow, antiSnipingWindow);
    });

    testWidgets('an extension shows "+30 sn" for a moment', (tester) async {
      Widget countdown(Duration left) =>
          Countdown(endsAt: start.add(left), clock: () => start);
      await pumpThemed(tester, countdown(const Duration(seconds: 5)));
      expect(find.byType(ExtensionChip), findsNothing);

      await pumpThemed(tester, countdown(const Duration(seconds: 35)));
      await tester.pump(AppDurations.extend);
      expect(find.text('+30 sn'), findsOneWidget);

      await tester.pump(extensionChipVisible);
      await tester.pumpAndSettle();
      expect(find.text('+30 sn'), findsNothing);
    });

    testWidgets('never shows negative time', (tester) async {
      await pumpThemed(
        tester,
        Countdown(
          endsAt: start,
          clock: () => start.add(const Duration(minutes: 1)),
        ),
      );
      expect(find.text('00:00'), findsOneWidget);
    });

    test('formats hours when needed', () {
      expect(formatRemaining(const Duration(seconds: 59)), '00:59');
      expect(
        formatRemaining(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });
  });

  group('BidFeedRow', () {
    testWidgets('a long username is cut, the amount stays whole', (
      tester,
    ) async {
      await pumpThemed(
        tester,
        const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: AppSize.bidFeedWidth,
            child: BidFeedRow(
              username: 'cok_uzun_bir_kullanici_adi_123',
              amount: Money.kurus(99999900),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₺999.999'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final name = tester.widget<Text>(
        find.text('@cok_uzun_bir_kullanici_adi_123'),
      );
      expect(name.overflow, TextOverflow.ellipsis);
    });

    testWidgets('your own bid says "Sen"', (tester) async {
      await pumpThemed(
        tester,
        const BidFeedRow(
          username: 'deniz',
          amount: Money.kurus(1000),
          isMine: true,
        ),
      );
      expect(find.text('Sen'), findsOneWidget);
    });

    testWidgets('slides in, or only fades with reduced motion', (tester) async {
      const row = BidFeedRow(username: 'a', amount: Money.kurus(1000));
      await pumpThemed(tester, row);
      expect(_inside(BidFeedRow, SlideTransition), findsOneWidget);

      await pumpThemed(tester, row, reduceMotion: true);
      expect(_inside(BidFeedRow, SlideTransition), findsNothing);
    });
  });

  group('states', () {
    testWidgets('error view offers a retry', (tester) async {
      var retried = false;
      await pumpThemed(
        tester,
        ErrorView(message: 'Bağlantı yok.', onRetry: () => retried = true),
      );
      await tester.tap(find.text('Tekrar dene'));
      expect(retried, isTrue);
    });

    testWidgets('connection banner explains the problem', (tester) async {
      await pumpThemed(tester, const ConnectionBanner(), width: 320);
      expect(find.text(ConnectionBanner.text), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('app message uses the themed snackbar', (tester) async {
      await pumpThemed(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppMessage(
              context,
              'Limitine ulaştın.',
              tone: AppMessageTone.error,
            ),
            child: const Text('göster'),
          ),
        ),
      );
      await tester.tap(find.text('göster'));
      await tester.pump();

      expect(find.text('Limitine ulaştın.'), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
      // On the dark snackbar of the light theme.
      expect(icon.color, AppColors.errorOnDark);
    });
  });
}
