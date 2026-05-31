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

/// Inclusive calendar month for [monthStart] (any day in that month).
({DateTime start, DateTime end}) calendarMonthRange(DateTime monthStart) {
  final local = monthStart.toLocal();
  final start = DateTime(local.year, local.month, 1);
  final end = DateTime(
    local.year,
    local.month + 1,
    0,
    23,
    59,
    59,
    999,
    999,
  );
  return (start: start, end: end);
}

/// First day of [reference]'s month through end of [reference]'s calendar day.
({DateTime start, DateTime end}) currentMonthToDateRange([
  DateTime? reference,
]) {
  final ref = (reference ?? DateTime.now()).toLocal();
  final start = DateTime(ref.year, ref.month, 1);
  final end = DateTime(ref.year, ref.month, ref.day, 23, 59, 59, 999, 999);
  return (start: start, end: end);
}

/// The full calendar month immediately before [reference]'s month.
({DateTime start, DateTime end}) previousCalendarMonthRange([
  DateTime? reference,
]) {
  final ref = (reference ?? DateTime.now()).toLocal();
  final previousMonth = DateTime(ref.year, ref.month - 1, 1);
  return calendarMonthRange(previousMonth);
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
