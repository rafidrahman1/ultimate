import 'package:flutter/material.dart';

class TimeOfDayRange {
  const TimeOfDayRange({required this.start, required this.end});

  final TimeOfDay start;
  final TimeOfDay end;
}

String formatTimeLabel(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  if (time.minute == 0) return '$hour $period';
  return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
}

String formatTimeRange(TimeOfDay? start, TimeOfDay? end) {
  if (start == null || end == null) return '';
  return '${formatTimeLabel(start)} to ${formatTimeLabel(end)}';
}

TimeOfDay? parseTimeLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final match = RegExp(
    r'^(\d{1,2})(?::(\d{2}))?\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return null;

  var hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2) ?? '0');
  final period = match.group(3)!.toUpperCase();

  if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;

  if (period == 'AM') {
    hour = hour == 12 ? 0 : hour;
  } else {
    hour = hour == 12 ? 12 : hour + 12;
  }

  return TimeOfDay(hour: hour, minute: minute);
}

TimeOfDayRange? parseTimeRangeLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final match = RegExp(
    r'^(.+?)\s+to\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return null;

  final start = parseTimeLabel(match.group(1)!);
  final end = parseTimeLabel(match.group(2)!);
  if (start == null || end == null) return null;

  return TimeOfDayRange(start: start, end: end);
}
