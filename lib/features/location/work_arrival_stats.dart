import 'package:intl/intl.dart';

import 'package:personal/core/time_range_schedule.dart';
import 'package:personal/features/location/timeline_activity.dart';

const lateArrivalGraceBeforeWorkStartMinutes = 5;

class WorkArrivalThreshold {
  const WorkArrivalThreshold({required this.hour, required this.minute});

  final int hour;
  final int minute;

  String get label {
    final hourText = hour.toString().padLeft(2, '0');
    final minuteText = minute.toString().padLeft(2, '0');
    return '$hourText:$minuteText';
  }
}

WorkArrivalThreshold? lateArrivalThresholdFromWorkHours(
  String workHours, {
  int minutesBeforeStart = lateArrivalGraceBeforeWorkStartMinutes,
}) {
  final range = parseTimeRangeLabel(workHours.trim());
  if (range == null) return null;

  final start = range.start;
  final totalMinutes = start.hour * 60 + start.minute - minutesBeforeStart;
  if (totalMinutes < 0) {
    return const WorkArrivalThreshold(hour: 0, minute: 0);
  }

  return WorkArrivalThreshold(
    hour: totalMinutes ~/ 60,
    minute: totalMinutes % 60,
  );
}

class WorkDayArrival {
  const WorkDayArrival({
    required this.date,
    required this.arrivalTime,
  });

  final DateTime date;
  final DateTime arrivalTime;
}

class WorkArrivalStats {
  const WorkArrivalStats({
    required this.workDays,
    required this.lateArrivals,
    this.threshold,
  });

  static const empty = WorkArrivalStats(workDays: [], lateArrivals: []);

  final List<WorkDayArrival> workDays;
  final List<WorkDayArrival> lateArrivals;
  final WorkArrivalThreshold? threshold;

  int get totalWorkDays => workDays.length;
  int get lateArrivalCount => lateArrivals.length;
  bool get hasWorkVisits => workDays.isNotEmpty;
  bool get hasLateThreshold => threshold != null;

  String get thresholdLabel => threshold?.label ?? '';

  static WorkArrivalStats analyze({
    required List<TimelinePlaceVisit> placeVisits,
    String workAddress = '',
    String workHours = '',
    int minutesBeforeStart = lateArrivalGraceBeforeWorkStartMinutes,
  }) {
    final workVisits = placeVisits
        .where((visit) => isWorkPlaceVisit(visit, workAddress.trim()))
        .toList();
    if (workVisits.isEmpty) return WorkArrivalStats.empty;

    final threshold = lateArrivalThresholdFromWorkHours(
      workHours,
      minutesBeforeStart: minutesBeforeStart,
    );

    final firstArrivalByDay = <String, WorkDayArrival>{};
    for (final visit in workVisits) {
      final localStart = visit.startTime.toLocal();
      final dayKey = _dayKey(localStart);
      final existing = firstArrivalByDay[dayKey];
      if (existing == null || localStart.isBefore(existing.arrivalTime)) {
        firstArrivalByDay[dayKey] = WorkDayArrival(
          date: DateTime(localStart.year, localStart.month, localStart.day),
          arrivalTime: localStart,
        );
      }
    }

    final workDays = firstArrivalByDay.values.toList()
      ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    final lateArrivals = threshold == null
        ? const <WorkDayArrival>[]
        : workDays
            .where(
              (day) => isArrivalAfterThreshold(
                day.arrivalTime,
                hour: threshold.hour,
                minute: threshold.minute,
              ),
            )
            .toList();

    return WorkArrivalStats(
      workDays: workDays,
      lateArrivals: lateArrivals,
      threshold: threshold,
    );
  }

  String toPromptLine() {
    if (!hasWorkVisits) return '';
    if (!hasLateThreshold) {
      return 'Work visits tracked: $totalWorkDays workdays.';
    }

    final timeFormat = DateFormat('d MMM, h:mm a');
    final lateDetails = lateArrivals
        .map((day) => timeFormat.format(day.arrivalTime))
        .join('; ');
    final buffer = StringBuffer(
      'Work arrivals after $thresholdLabel: $lateArrivalCount of $totalWorkDays workdays',
    );
    if (lateArrivals.isNotEmpty) {
      buffer.write(' ($lateDetails)');
    }
    buffer.write('.');
    return buffer.toString();
  }
}

bool isArrivalAfterThreshold(
  DateTime localArrival, {
  required int hour,
  required int minute,
}) {
  final thresholdMinutes = hour * 60 + minute;
  final arrivalMinutes = localArrival.hour * 60 + localArrival.minute;
  return arrivalMinutes > thresholdMinutes;
}

bool isWorkPlaceVisit(TimelinePlaceVisit visit, String workAddress) {
  if (visit.isWork) return true;
  if (workAddress.isEmpty) return false;
  return _matchesWorkAddress(visit, workAddress);
}

bool _matchesWorkAddress(TimelinePlaceVisit visit, String workAddress) {
  final work = _normalizeLocationText(workAddress);

  final name = _normalizeLocationText(visit.name);
  if (name == 'work') return true;

  final address = _normalizeLocationText(visit.address ?? '');
  final haystack = '$name $address'.trim();
  if (haystack.isEmpty) return false;

  if (haystack.contains(work) || (name.length >= 4 && work.contains(name))) {
    return true;
  }

  final tokens = work
      .split(RegExp(r'[,\s]+'))
      .where((token) => token.length >= 4)
      .toList();
  if (tokens.isEmpty) return false;

  final matchedTokens = tokens.where((token) => haystack.contains(token)).length;
  if (tokens.length == 1) return matchedTokens == 1;
  return matchedTokens >= 2;
}

String _normalizeLocationText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _dayKey(DateTime localDateTime) {
  return '${localDateTime.year}-${localDateTime.month}-${localDateTime.day}';
}
