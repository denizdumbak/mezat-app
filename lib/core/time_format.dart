const _months = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

/// When an upcoming auction starts, as people say it: "Bugün 20:00",
/// "Yarın 09:30", otherwise "26 Eki 20:00".
String formatStartsAt(DateTime startsAt, {required DateTime now}) {
  final local = startsAt.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return switch (day.difference(today).inDays) {
    0 => 'Bugün $time',
    1 => 'Yarın $time',
    _ => '${local.day} ${_months[local.month - 1]} $time',
  };
}

/// A spending-limit window in its largest whole unit: "6 saat", "1 gün",
/// "2 hafta", "1 ay" (exactly 30 days).
String formatPeriod(Duration period) {
  final (count, unit) = _periodParts(period);
  return '$count $unit';
}

/// The same with the locative ending, as in "Son 6 saatte", "Son 1 günde".
String formatPeriodIn(Duration period) {
  final (count, unit) = _periodParts(period);
  final ending = switch (unit) {
    'saat' => 'saatte',
    'gün' => 'günde',
    'hafta' => 'haftada',
    _ => 'ayda',
  };
  return '$count $ending';
}

(int, String) _periodParts(Duration period) {
  final hours = period.inHours;
  if (period == const Duration(days: 30)) return (1, 'ay');
  if (hours % (24 * 7) == 0) return (hours ~/ (24 * 7), 'hafta');
  if (hours % 24 == 0) return (hours ~/ 24, 'gün');
  return (hours, 'saat');
}

/// "128", "1,2 B" (bin), "12 B": viewer counts stay short.
String formatCount(int count) {
  if (count < 1000) return '$count';
  if (count < 10000) {
    final tenths = (count / 100).floor();
    return tenths % 10 == 0
        ? '${tenths ~/ 10} B'
        : '${tenths ~/ 10},${tenths % 10} B';
  }
  return '${count ~/ 1000} B';
}
