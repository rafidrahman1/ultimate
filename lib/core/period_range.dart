import 'package:intl/intl.dart';

/// Inclusive calendar-day range label, e.g. "16 Apr 2026 – 23 May 2026".
String formatPeriodRange(DateTime start, DateTime end) {
  final dateFormat = DateFormat('d MMM yyyy');
  final startLabel = dateFormat.format(start.toLocal());
  final endLabel = dateFormat.format(end.toLocal());
  if (startLabel == endLabel) return startLabel;
  return '$startLabel – $endLabel';
}

DateTime? minDateTime(Iterable<DateTime> values) {
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a.isBefore(b) ? a : b);
}

DateTime? maxDateTime(Iterable<DateTime> values) {
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a.isAfter(b) ? a : b);
}

/// From the first day of [monthStart]'s month through the last moment of the next month.
({DateTime start, DateTime end}) monthAndNextMonthRange(DateTime monthStart) {
  final local = monthStart.toLocal();
  final start = DateTime(local.year, local.month, 1);
  final end = DateTime(
    local.year,
    local.month + 2,
    0,
    23,
    59,
    59,
    999,
    999,
  );
  return (start: start, end: end);
}
