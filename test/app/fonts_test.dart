import 'package:flutter_test/flutter_test.dart';

import '../helpers/font_file.dart';

/// Every Turkish letter and the lira sign. A missing glyph would fall back
/// to another font (or a box) in the middle of a word.
const turkishSample = 'ÇĞİIÖŞÜ çğıiöşü ₺';

const _fonts = [
  'Manrope-Regular',
  'Manrope-Medium',
  'Manrope-SemiBold',
  'Manrope-Bold',
  'Manrope-ExtraBold',
];

void main() {
  for (final name in _fonts) {
    test('$name has every Turkish letter, ₺ and digits', () {
      final font = FontFile.read('assets/fonts/$name.ttf');
      final missing = [
        for (final rune in '${turkishSample}0123456789.,'.runes)
          if (rune != 0x20 && !font.hasGlyph(rune)) String.fromCharCode(rune),
      ];
      expect(missing, isEmpty);
    });
  }

  test('Manrope has tabular figures for prices and countdowns', () {
    for (final name in _fonts) {
      expect(
        FontFile.read('assets/fonts/$name.ttf').substitutionFeatures,
        contains('tnum'),
        reason: name,
      );
    }
  });

  test('the reader really detects a missing glyph', () {
    // U+4E00 (a CJK character) is not in a Latin font; guards against a
    // reader that says "yes" to everything.
    expect(
      FontFile.read('assets/fonts/Manrope-Regular.ttf').hasGlyph(0x4E00),
      isFalse,
    );
  });
}
