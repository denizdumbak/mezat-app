import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/app/design_tokens.dart';
import 'package:mezat_app/app/theme.dart';

import '../helpers/app_fonts.dart';
import 'fonts_test.dart' show turkishSample;

/// WCAG relative luminance contrast ratio.
double _contrast(Color a, Color b) {
  double luminance(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  final (l1, l2) = (luminance(a), luminance(b));
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  group('contrast (WCAG AA needs 4.5:1 for body text)', () {
    // The ratios DESIGN.md promises, rounded down to one decimal.
    final pairs = {
      'onStage on stage': (AppColors.onStage, AppColors.stage, 15.0),
      'onStageMuted on stage': (AppColors.onStageMuted, AppColors.stage, 8.5),
      'onStageMuted on stageRaised': (
        AppColors.onStageMuted,
        AppColors.stageRaised,
        7.5,
      ),
      'onGold on gold': (AppColors.onGold, AppColors.gold, 8.4),
      'urgent on stage': (AppColors.urgent, AppColors.stage, 6.5),
      'urgent on stageRaised': (AppColors.urgent, AppColors.stageRaised, 5.7),
      'success on stage': (AppColors.success, AppColors.stage, 8.2),
    };
    for (final MapEntry(key: name, value: (fg, bg, atLeast)) in pairs.entries) {
      test(name, () {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(atLeast));
      });
    }
  });

  group('theme', () {
    test('is dark and maps the palette, not a seed colour', () {
      final scheme = appTheme.colorScheme;
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, AppColors.gold);
      expect(scheme.onPrimary, AppColors.onGold);
      expect(scheme.surface, AppColors.stage);
      expect(scheme.surfaceContainerHighest, AppColors.stageRaised);
      expect(scheme.error, AppColors.urgent);
      expect(appTheme.scaffoldBackgroundColor, AppColors.stage);
    });

    test('headings use Fraunces, body text Manrope', () {
      final text = appTheme.textTheme;
      expect(text.headlineSmall!.fontFamily, AppFonts.display);
      expect(text.titleLarge!.fontFamily, AppFonts.display);
      expect(text.bodyMedium!.fontFamily, AppFonts.body);
      expect(text.labelLarge!.fontFamily, AppFonts.body);
    });

    test('prices and timers use tabular figures', () {
      for (final style in [
        AppTextStyles.priceLarge,
        AppTextStyles.price,
        AppTextStyles.timer,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
      expect(AppTextStyles.priceLarge.fontSize, 40);
    });

    test('only the two radii are used for shapes', () {
      final card = appTheme.cardTheme.shape! as RoundedRectangleBorder;
      expect(card.borderRadius, AppRadius.largeAll);
      final snack = appTheme.snackBarTheme.shape! as RoundedRectangleBorder;
      expect(snack.borderRadius, AppRadius.smallAll);
    });
  });

  testWidgets('Turkish text renders with the bundled fonts', (tester) async {
    await loadAppFonts();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Column(
            children: [
              Builder(
                builder: (context) => Text(
                  turkishSample,
                  key: const Key('heading'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const Text(turkishSample, key: Key('body')),
            ],
          ),
        ),
      ),
    );

    RenderParagraph paragraph(String key) =>
        tester.renderObject<RenderParagraph>(find.byKey(Key(key)));
    expect(paragraph('heading').text.style!.fontFamily, AppFonts.display);
    // Body text inherits the theme's default family.
    expect(
      DefaultTextStyle.of(
        tester.element(find.byKey(const Key('body'))),
      ).style.fontFamily,
      AppFonts.body,
    );
    // Every character laid out on one line, none dropped: the text the
    // paragraph holds is exactly the sample.
    expect(paragraph('body').text.toPlainText(), turkishSample);
    expect(paragraph('body').didExceedMaxLines, isFalse);
  });
}
