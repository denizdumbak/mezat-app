import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';
import 'package:mezat_app/core/photo_picker.dart';
import 'package:mezat_app/features/auctions/auction_validators.dart';
import 'package:mezat_app/features/auctions/create_auction_screen.dart';

void main() {
  group('validateTitle', () {
    test('accepts 3–80 characters after trimming', () {
      expect(validateTitle('Kamera'), isNull);
      expect(validateTitle('  abc  '), isNull);
      expect(validateTitle('a' * 80), isNull);
    });

    test('rejects what the database rejects', () {
      expect(validateTitle(''), 'Bir başlık yaz.');
      expect(validateTitle('  ab  '), 'Başlık 3–80 karakter olmalı.');
      expect(validateTitle('a' * 81), 'Başlık 3–80 karakter olmalı.');
    });
  });

  test('description is optional, up to 2000 characters', () {
    expect(validateDescription(''), isNull);
    expect(validateDescription('a' * 2000), isNull);
    expect(validateDescription('a' * 2001), isNotNull);
  });

  group('validateAmount', () {
    test('accepts positive amounts in Turkish style', () {
      expect(validateAmount('150'), isNull);
      expect(validateAmount('1.250,50'), isNull);
    });

    test('explains what is wrong', () {
      expect(validateAmount(''), 'Bir tutar gir.');
      expect(
        validateAmount('on lira'),
        'Geçerli bir tutar gir (ör. 1.250,50).',
      );
      expect(validateAmount('0'), 'Tutar 0\'dan büyük olmalı.');
      expect(validateAmount('0,00'), 'Tutar 0\'dan büyük olmalı.');
    });
  });

  group('validateScheduledStart', () {
    final now = DateTime(2026, 10, 24, 12);

    test('accepts a time in the next 30 days', () {
      expect(
        validateScheduledStart(now.add(const Duration(hours: 1)), now: now),
        isNull,
      );
      expect(
        validateScheduledStart(now.add(const Duration(days: 30)), now: now),
        isNull,
      );
    });

    test('rejects missing, past and too distant times', () {
      expect(
        validateScheduledStart(null, now: now),
        'Başlangıç tarihi ve saatini seç.',
      );
      expect(
        validateScheduledStart(now, now: now),
        'Başlangıç zamanı gelecekte olmalı.',
      );
      expect(
        validateScheduledStart(
          now.add(const Duration(days: 30, minutes: 1)),
          now: now,
        ),
        'Mezat en fazla 30 gün sonrasına planlanabilir.',
      );
    });
  });

  group('increment chips', () {
    const min = Money.kurus(2500);

    test('empty is fine; others follow the amount rules', () {
      expect(validateIncrement(''), isNull);
      expect(validateIncrement('  '), isNull);
      expect(validateIncrement('abc'), 'Geçerli bir tutar gir (ör. 1.250,50).');
      expect(validateIncrement('0'), "Tutar 0'dan büyük olmalı.");
    });

    test('a chip below the minimum is refused, equal is fine', () {
      expect(validateIncrement('10', minIncrement: min), 'En az ₺25');
      expect(validateIncrement('25', minIncrement: min), isNull);
      // Without a valid minimum there is nothing to compare with yet.
      expect(validateIncrement('10'), isNull);
    });

    test('a repeated chip is refused', () {
      expect(
        validateIncrement('50', earlier: const [Money.kurus(5000)]),
        'Tekrar ediyor',
      );
    });

    test('filled chips are parsed smallest first, blanks skipped', () {
      expect(parseIncrements(['100', '', ' 25,50 ']), const [
        Money.kurus(2550),
        Money.kurus(10000),
      ]);
      expect(parseIncrements(['', '', '']), isEmpty);
    });
  });

  test('every duration option is inside the database range', () {
    expect(durationOptions, everyElement(inInclusiveRange(5, 180)));
    expect(durationOptions, contains(defaultDurationMinutes));
  });

  test('labels and dates read naturally in Turkish', () {
    expect(durationLabel(30), '30 dakika');
    expect(durationLabel(60), '1 saat');
    expect(durationLabel(90), '1 saat 30 dakika');
    expect(formatDateTime(DateTime(2026, 3, 4, 9, 5)), '04.03.2026 09:05');
  });

  test('photo content type comes from the file extension', () {
    expect(photoContentType('IMG_1.JPG'), 'image/jpeg');
    expect(photoContentType('a.jpeg'), 'image/jpeg');
    expect(photoContentType('a.png'), 'image/png');
    expect(photoContentType('a.webp'), 'image/webp');
    expect(photoContentType('a.heic'), isNull);
    expect(photoContentType('noextension'), isNull);
  });
}
