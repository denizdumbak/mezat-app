/// An amount of Turkish lira, stored as whole kuruş (1 TL = 100 kuruş).
///
/// Never a `double`: binary floating point cannot hold 0.10 exactly, so sums
/// drift (0.1 + 0.2 != 0.3). The database column is `numeric(12,2)`; amounts
/// travel to and from it as text ("1250.50"), never as JSON numbers.
class Money implements Comparable<Money> {
  const Money.kurus(this.kurus);

  final int kurus;

  static const zero = Money.kurus(0);

  /// The largest value `numeric(12,2)` holds: 9.999.999.999,99 TL.
  static const max = Money.kurus(999999999999);

  static final _digits = RegExp(r'^\d+$');
  static final _fraction = RegExp(r'^\d{0,2}$');
  // "1.250" or "12.500.000": dots as thousands separators (Turkish style).
  static final _grouped = RegExp(r'^\d{1,3}(\.\d{3})+$');

  /// Parses what a user types, or returns null if it is not an amount.
  ///
  /// Turkish style is the default: "1.250,50" is 1250.50 TL and "1.250" is
  /// 1250 TL. A single dot followed by one or two digits ("12.5") is read as a
  /// decimal point, for keyboards that only offer a dot.
  static Money? tryParse(String raw) {
    final text = raw.replaceAll(RegExp(r'[\s₺]'), '');
    String whole;
    var fraction = '';
    if (text.contains(',')) {
      final parts = text.split(',');
      if (parts.length != 2) return null;
      whole = parts[0];
      fraction = parts[1];
      if (whole.contains('.')) {
        if (!_grouped.hasMatch(whole)) return null;
        whole = whole.replaceAll('.', '');
      }
    } else if (_grouped.hasMatch(text)) {
      whole = text.replaceAll('.', '');
    } else if (text.contains('.')) {
      final parts = text.split('.');
      if (parts.length != 2) return null;
      whole = parts[0];
      fraction = parts[1];
    } else {
      whole = text;
    }

    // More than 10 digits would not fit numeric(12,2) (and could overflow).
    if (!_digits.hasMatch(whole) || whole.length > 10) return null;
    if (!_fraction.hasMatch(fraction)) return null;
    final kurus = int.parse(whole) * 100 + int.parse(fraction.padRight(2, '0'));
    return kurus > max.kurus ? null : Money.kurus(kurus);
  }

  /// Parses the database's text form, e.g. "1250.50".
  factory Money.parseDb(String raw) {
    final [whole, fraction] = raw.contains('.') ? raw.split('.') : [raw, ''];
    return Money.kurus(
      int.parse(whole) * 100 + int.parse(fraction.padRight(2, '0')),
    );
  }

  /// The text form the database expects, e.g. "1250.50".
  String toDb() =>
      '${kurus ~/ 100}.${(kurus % 100).toString().padLeft(2, '0')}';

  /// For display: "₺1.250,50", or "₺150" when there are no kuruş.
  String format() {
    final lira = (kurus ~/ 100).toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+$)'),
      (_) => '.',
    );
    final rest = kurus % 100;
    return rest == 0 ? '₺$lira' : '₺$lira,${rest.toString().padLeft(2, '0')}';
  }

  bool get isPositive => kurus > 0;

  Money operator +(Money other) => Money.kurus(kurus + other.kurus);

  @override
  int compareTo(Money other) => kurus.compareTo(other.kurus);

  @override
  bool operator ==(Object other) => other is Money && other.kurus == kurus;

  @override
  int get hashCode => kurus.hashCode;

  @override
  String toString() => 'Money(${toDb()})';
}
