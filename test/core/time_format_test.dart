import 'package:flutter_test/flutter_test.dart';
import 'package:mezat_app/core/time_format.dart';

void main() {
  final now = DateTime(2026, 10, 24, 15);

  test('start times read as people say them', () {
    expect(formatStartsAt(DateTime(2026, 10, 24, 20), now: now), 'Bugün 20:00');
    expect(
      formatStartsAt(DateTime(2026, 10, 25, 9, 5), now: now),
      'Yarın 09:05',
    );
    expect(
      formatStartsAt(DateTime(2026, 10, 28, 20), now: now),
      '28 Eki 20:00',
    );
    expect(formatStartsAt(DateTime(2027, 2, 1, 20), now: now), '1 Şub 20:00');
  });

  test('viewer counts stay short', () {
    expect(formatCount(128), '128');
    expect(formatCount(1000), '1 B');
    expect(formatCount(1250), '1,2 B');
    expect(formatCount(12500), '12 B');
  });
}
