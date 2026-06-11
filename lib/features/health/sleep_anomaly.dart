import 'package:personal/features/health/health_summary.dart';

const sleepShortThreshold = Duration(hours: 6);
const sleepVeryShortThreshold = Duration(hours: 4);
const sleepLateBedtimeAfterHour = 2;
const sleepLateBedtimeAfterMinute = 0;
const sleepEarlyWakeBeforeHour = 6;

bool isSleepAnomalyNight(DailySleepEntry entry) {
  if (!entry.hasData) return false;
  return entry.session!.duration < sleepShortThreshold;
}

bool isLateBedtimeNight(DailySleepEntry entry) {
  if (!entry.hasData) return false;
  return _isLateBedtime(entry.session!.startTime);
}

int countSleepAnomaliesInWakeDateRange(
  List<DailySleepEntry> nights,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final start = _dateOnly(rangeStart);
  final end = _dateOnly(rangeEnd);
  return nights
      .where(
        (night) =>
            night.hasData &&
            !_dateOnly(night.wakeDate).isBefore(start) &&
            !_dateOnly(night.wakeDate).isAfter(end) &&
            isSleepAnomalyNight(night),
      )
      .length;
}

int countLateBedtimesInWakeDateRange(
  List<DailySleepEntry> nights,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final start = _dateOnly(rangeStart);
  final end = _dateOnly(rangeEnd);
  return nights
      .where(
        (night) =>
            night.hasData &&
            !_dateOnly(night.wakeDate).isBefore(start) &&
            !_dateOnly(night.wakeDate).isAfter(end) &&
            isLateBedtimeNight(night),
      )
      .length;
}

bool _isLateBedtime(DateTime bedtime) {
  final hour = bedtime.hour;
  if (hour >= 18 || (hour >= 6 && hour < 18)) return false;

  final afterMinutes =
      sleepLateBedtimeAfterHour * 60 + sleepLateBedtimeAfterMinute;
  final bedtimeMinutes = hour * 60 + bedtime.minute;
  return bedtimeMinutes > afterMinutes;
}

DateTime _dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);
