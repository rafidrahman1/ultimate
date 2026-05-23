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
