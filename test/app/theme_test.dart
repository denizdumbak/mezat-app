import 'dart:io';
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
  group('contrast (WCAG AA: 4.5:1 for text, 3:1 for large text and icons)', () {
    // The ratios DESIGN.md promises, rounded down to one decimal.
    final soldBackdrop = Color.alphaBlend(
      AppColors.scrimStrong,
      AppColors.liveSurface,
    );
    final pairs = {
      'text on surface': (AppColors.text, AppColors.surface, 19.0),
      'textMuted on surface': (AppColors.textMuted, AppColors.surface, 7.7),
      'textMuted on surfaceAlt': (
        AppColors.textMuted,
        AppColors.surfaceAlt,
        7.0,
      ),
      'error on surface': (AppColors.error, AppColors.surface, 4.8),
      'liveText on liveSurface': (
        AppColors.liveText,
        AppColors.liveSurface,
        19.0,
      ),
      'liveTextMuted on liveSurface': (
        AppColors.liveTextMuted,
        AppColors.liveSurface,
        7.7,
      ),
      'errorOnDark on liveSurface': (
        AppColors.errorOnDark,
        AppColors.liveSurface,
        7.1,
      ),
      'onAccent on accent': (AppColors.onAccent, AppColors.accent, 10.8),
      // The SATILDI stamp: success green on the strong scrim over the room.
      'success on the sold backdrop': (AppColors.success, soldBackdrop, 6.0),
      // "CANLI" is white on live red: large-text level only (DESIGN.md).
      'white on live red': (AppColors.liveText, AppColors.live, 3.7),
    };
    for (final MapEntry(key: name, value: (fg, bg, atLeast)) in pairs.entries) {
      test(name, () {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(atLeast));
      });
    }
  });

  group('themes', () {
    test('browse is light and maps the palette, not a seed colour', () {
      final scheme = browseTheme.colorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.primary, AppColors.accent);
      expect(scheme.onPrimary, AppColors.onAccent);
      expect(scheme.surface, AppColors.surface);
      expect(scheme.onSurface, AppColors.text);
      expect(scheme.onSurfaceVariant, AppColors.textMuted);
      expect(scheme.surfaceContainerHighest, AppColors.surfaceAlt);
      expect(scheme.outlineVariant, AppColors.line);
      expect(scheme.error, AppColors.error);
      expect(browseTheme.scaffoldBackgroundColor, AppColors.surface);
      expect(browseTheme.extension<AppPalette>()!.panelBlurred, isFalse);
    });

    test('live is dark, with see-through blurred panels', () {
      final scheme = liveTheme.colorScheme;
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, AppColors.accent);
      expect(scheme.surface, AppColors.liveSurface);
      expect(scheme.onSurface, AppColors.liveText);
      expect(scheme.onSurfaceVariant, AppColors.liveTextMuted);
      expect(scheme.outlineVariant, AppColors.liveLine);
      expect(scheme.error, AppColors.errorOnDark);
      final palette = liveTheme.extension<AppPalette>()!;
      expect(palette.panel, AppColors.scrim);
      expect(palette.panelBlurred, isTrue);
    });

    test('no navy anywhere', () {
      for (final theme in [browseTheme, liveTheme]) {
        final scheme = theme.colorScheme;
        for (final color in [
          scheme.surface,
          scheme.surfaceContainerHighest,
          scheme.onSurface,
          scheme.primary,
        ]) {
          // Navy has a blue channel well above red and green.
          expect(color.b - color.r, lessThan(0.05), reason: '$color');
        }
      }
    });
  });

  group('type', () {
    test('one family, Manrope, in every role', () {
      final text = browseTheme.textTheme;
      for (final style in [
        text.headlineMedium,
        text.titleLarge,
        text.titleMedium,
        text.bodyLarge,
        text.bodySmall,
        text.labelLarge,
        text.labelSmall,
      ]) {
        expect(style!.fontFamily, AppFonts.body);
      }
    });

    test('the scale: title 22, headline 17, body 15, label 13, caption 12', () {
      final text = browseTheme.textTheme;
      expect(text.titleLarge!.fontSize, 22);
      expect(text.headlineMedium!.fontSize, 22);
      expect(text.titleMedium!.fontSize, 17);
      expect(text.labelLarge!.fontSize, 17);
      expect(text.bodyLarge!.fontSize, 15);
      expect(text.bodyMedium!.fontSize, 15);
      expect(text.labelMedium!.fontSize, 13);
      expect(text.bodySmall!.fontSize, 12);
      expect(text.labelSmall!.fontSize, 12);
    });

    test('nothing is smaller than 12', () {
      for (final theme in [browseTheme, liveTheme]) {
        final text = theme.textTheme;
        for (final style in [
          text.displayLarge,
          text.displayMedium,
          text.displaySmall,
          text.headlineLarge,
          text.headlineMedium,
          text.headlineSmall,
          text.titleLarge,
          text.titleMedium,
          text.titleSmall,
          text.bodyLarge,
          text.bodyMedium,
          text.bodySmall,
          text.labelLarge,
          text.labelMedium,
          text.labelSmall,
        ]) {
          expect(style!.fontSize, greaterThanOrEqualTo(12));
        }
      }
    });

    test('prices and timers are tabular and w800', () {
      for (final style in [
        AppTextStyles.priceDisplay,
        AppTextStyles.price,
        AppTextStyles.timer,
      ]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(style.fontWeight, FontWeight.w800);
      }
      expect(AppTextStyles.priceDisplay.fontSize, 40);
      expect(AppTextStyles.priceDisplay.height! * 40, closeTo(44, 0.01));
    });
  });

  group('shapes', () {
    test('cards 16, sheets 24 on top, buttons and chips are pills', () {
      final card = browseTheme.cardTheme.shape! as RoundedRectangleBorder;
      expect(card.borderRadius, AppRadius.cardAll);
      expect(card.side, BorderSide.none);
      final sheet =
          browseTheme.bottomSheetTheme.shape! as RoundedRectangleBorder;
      expect(sheet.borderRadius, AppRadius.sheetTop);
      expect(
        browseTheme.filledButtonTheme.style!.shape!.resolve({}),
        isA<StadiumBorder>(),
      );
      final field =
          browseTheme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(field.borderRadius, AppRadius.imageAll);
    });
  });

  test('widgets read colours from the theme, never AppColors', () {
    // Two themes: a hard-coded colour would be right in only one of them.
    final offenders = [
      for (final dir in ['lib/core', 'lib/features'])
        for (final file in Directory(dir).listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              file.readAsStringSync().contains('AppColors.'))
            file.path,
    ];
    expect(offenders, isEmpty);
  });

  testWidgets('Turkish text renders with the bundled font', (tester) async {
    await loadAppFonts();
    await tester.pumpWidget(
      MaterialApp(
        theme: browseTheme,
        home: Scaffold(
          body: Column(
            children: [
              Builder(
                builder: (context) => Text(
                  turkishSample,
                  key: const Key('heading'),
                  style: Theme.of(context).textTheme.titleLarge,
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
    expect(paragraph('heading').text.style!.fontFamily, AppFonts.body);
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
