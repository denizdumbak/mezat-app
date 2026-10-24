import '../../core/money.dart';

// These mirror the check constraints and the insert trigger on
// public.auctions, so most mistakes are caught before any request.

const minTitleLength = 3;
const maxTitleLength = 80;
const maxDescriptionLength = 2000;

/// Choices for the duration dropdown; all inside the database's 5–180 range.
const durationOptions = [5, 10, 15, 30, 45, 60, 90, 120, 180];
const defaultDurationMinutes = 30;

/// How far ahead an auction may be scheduled.
const maxScheduleAhead = Duration(days: 30);

String? validateTitle(String? raw) {
  final title = (raw ?? '').trim();
  if (title.isEmpty) return 'Bir başlık yaz.';
  if (title.length < minTitleLength || title.length > maxTitleLength) {
    return 'Başlık $minTitleLength–$maxTitleLength karakter olmalı.';
  }
  return null;
}

String? validateDescription(String? raw) =>
    (raw ?? '').trim().length > maxDescriptionLength
    ? 'Açıklama en fazla $maxDescriptionLength karakter olabilir.'
    : null;

String? validateAmount(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return 'Bir tutar gir.';
  final amount = Money.tryParse(text);
  if (amount == null) return 'Geçerli bir tutar gir (ör. 1.250,50).';
  if (!amount.isPositive) return 'Tutar 0\'dan büyük olmalı.';
  return null;
}

/// One of the optional increment chip fields. Empty is fine. A chip below
/// [minIncrement] (when that field is already valid) or equal to one of the
/// [earlier] fields is refused, as the database would refuse it.
String? validateIncrement(
  String? raw, {
  Money? minIncrement,
  List<Money> earlier = const [],
}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return null;
  final amountError = validateAmount(text);
  if (amountError != null) return amountError;
  final amount = Money.tryParse(text)!;
  if (minIncrement != null && minIncrement > amount) {
    return 'En az ${minIncrement.format()}';
  }
  if (earlier.contains(amount)) return 'Tekrar ediyor';
  return null;
}

/// The filled chip fields as amounts, smallest first (the order the room
/// shows them). Call after the fields are validated.
List<Money> parseIncrements(Iterable<String> raws) => [
  for (final raw in raws)
    if (raw.trim().isNotEmpty) Money.tryParse(raw.trim())!,
]..sort();

/// For a scheduled start; "start now" needs no check.
String? validateScheduledStart(DateTime? startsAt, {required DateTime now}) {
  if (startsAt == null) return 'Başlangıç tarihi ve saatini seç.';
  if (!startsAt.isAfter(now)) return 'Başlangıç zamanı gelecekte olmalı.';
  if (startsAt.isAfter(now.add(maxScheduleAhead))) {
    return 'Mezat en fazla 30 gün sonrasına planlanabilir.';
  }
  return null;
}

/// "24.10.2026 14:05", in the device's time zone.
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
