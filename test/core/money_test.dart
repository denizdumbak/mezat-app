import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/money.dart';

void main() {
  group('Money.tryParse', () {
    final valid = {
      '150': 15000,
      '150,5': 15050,
      '150,50': 15050,
      '0,05': 5,
      '1.250,50': 125050,
      '12.500.000': 1250000000,
      // Turkish thousands separator, not a decimal point.
      '1.250': 125000,
      // A single dot with one or two digits after it is a decimal point.
      '12.5': 1250,
      '12.50': 1250,
      ' 1 250 ₺ ': 125000,
      '9999999999,99': 999999999999,
    };
    for (final MapEntry(key: input, value: kurus) in valid.entries) {
      test('"$input" is $kurus kuruş', () {
        expect(Money.tryParse(input), Money.kurus(kurus));
      });
    }

    for (final input in [
      '',
      'abc',
      '-5',
      '1,2,3',
      '1,234',
      '1.25.0',
      '1.2345',
      ',50',
      '12a',
      // 11 digits: more than numeric(12,2) holds.
      '10000000000',
    ]) {
      test('"$input" is not an amount', () {
        expect(Money.tryParse(input), isNull);
      });
    }
  });

  group('database text form', () {
    test('toDb always has two decimals', () {
      expect(const Money.kurus(125050).toDb(), '1250.50');
      expect(const Money.kurus(5).toDb(), '0.05');
      expect(const Money.kurus(15000).toDb(), '150.00');
    });

    test('parseDb reads what Postgres returns', () {
      expect(Money.parseDb('1250.50'), const Money.kurus(125050));
      expect(Money.parseDb('0.05'), const Money.kurus(5));
      expect(Money.parseDb('100'), const Money.kurus(10000));
      expect(Money.parseDb('9999999999.99'), Money.max);
    });

    test('round trip keeps every kuruş', () {
      for (final kurus in [1, 10, 99, 100, 123456789, Money.max.kurus]) {
        expect(Money.parseDb(Money.kurus(kurus).toDb()).kurus, kurus);
      }
    });
  });

  group('format', () {
    test('Turkish style, kuruş only when there are some', () {
      expect(const Money.kurus(125050).format(), '₺1.250,50');
      expect(const Money.kurus(15000).format(), '₺150');
      expect(const Money.kurus(5).format(), '₺0,05');
      expect(const Money.kurus(100000000).format(), '₺1.000.000');
    });
  });

  test('adds and compares without floating point error', () {
    // 0.10 + 0.20 is not 0.30 in doubles; in kuruş it is.
    expect(
      Money.tryParse('0,10')! + Money.tryParse('0,20')!,
      Money.tryParse('0,30'),
    );
    expect(const Money.kurus(1).compareTo(const Money.kurus(2)), lessThan(0));
    expect(Money.zero.isPositive, isFalse);
  });
}
