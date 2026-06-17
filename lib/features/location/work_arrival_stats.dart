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
    this.scheduledArrival,
  });

  final DateTime date;
  final DateTime arrivalTime;
  final DateTime? scheduledArrival;

  int? get delayMinutes {
    if (scheduledArrival == null) return null;
    final scheduledMinutes =
        scheduledArrival!.hour * 60 + scheduledArrival!.minute;
    final arrivalMinutes = arrivalTime.hour * 60 + arrivalTime.minute;
    final delay = arrivalMinutes - scheduledMinutes;
    return delay > 0 ? delay : 0;
  }

  bool get isLate => (delayMinutes ?? 0) > 0;
}

class WorkArrivalStats {
  const WorkArrivalStats({
    required this.workDays,
    required this.lateArrivals,
    this.threshold,
    this.workHours = '',
  });

  static const empty = WorkArrivalStats(workDays: [], lateArrivals: []);

  final List<WorkDayArrival> workDays;
  final List<WorkDayArrival> lateArrivals;
  final WorkArrivalThreshold? threshold;
  final String workHours;

  int get totalWorkDays => workDays.length;
  int get lateArrivalCount => lateArrivals.length;
  bool get hasWorkVisits => workDays.isNotEmpty;
  bool get hasLateThreshold => threshold != null;

  String get thresholdLabel => threshold?.label ?? '';

  int get totalLateMinutes => lateArrivals.fold<int>(
        0,
        (sum, arrival) => sum + (arrival.delayMinutes ?? 0),
      );

  double? get averageDelayMinutes {
    if (lateArrivals.isEmpty) return null;
    return totalLateMinutes / lateArrivals.length;
  }

  int? get worstDelayMinutes {
    if (lateArrivals.isEmpty) return null;
    return lateArrivals
        .map((arrival) => arrival.delayMinutes ?? 0)
        .reduce((a, b) => a > b ? a : b);
  }

  double? get lateArrivalRate {
    if (totalWorkDays <= 0) return null;
    return lateArrivalCount / totalWorkDays * 100;
  }

  DateTime? get scheduledArrivalTime {
    final range = parseTimeRangeLabel(workHours);
    if (range == null) return null;
    final start = range.start;
    return DateTime(2000, 1, 1, start.hour, start.minute);
  }

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
    final workRange = parseTimeRangeLabel(workHours.trim());
    final scheduledStart = workRange?.start;

    final firstArrivalByDay = <String, WorkDayArrival>{};
    for (final visit in workVisits) {
      final localStart = visit.startTime.toLocal();
      final dayKey = _dayKey(localStart);
      final scheduled = scheduledStart == null
          ? null
          : DateTime(
              localStart.year,
              localStart.month,
              localStart.day,
              scheduledStart.hour,
              scheduledStart.minute,
            );
      final existing = firstArrivalByDay[dayKey];
      if (existing == null || localStart.isBefore(existing.arrivalTime)) {
        firstArrivalByDay[dayKey] = WorkDayArrival(
          date: DateTime(localStart.year, localStart.month, localStart.day),
          arrivalTime: localStart,
          scheduledArrival: scheduled,
        );
      }
    }

    final workDays = firstArrivalByDay.values.toList()
      ..sort((a, b) => a.arrivalTime.compareTo(b.arrivalTime));

    final lateArrivals = scheduledStart == null
        ? const <WorkDayArrival>[]
        : workDays.where((day) => day.isLate).toList();

    return WorkArrivalStats(
      workDays: workDays,
      lateArrivals: lateArrivals,
      threshold: threshold,
      workHours: workHours,
    );
  }

  String toPromptLine() {
    if (!hasWorkVisits) return '';
    if (!hasLateThreshold) {
      return 'Work visits tracked: $totalWorkDays workdays.';
    }

    final scheduled = scheduledArrivalTime;
    final scheduledLabel = scheduled == null
        ? 'scheduled start'
        : '${scheduled.hour.toString().padLeft(2, '0')}:'
            '${scheduled.minute.toString().padLeft(2, '0')}';
    final timeFormat = DateFormat('d MMM, h:mm a');
    final lateDetails = lateArrivals
        .map((day) => timeFormat.format(day.arrivalTime))
        .join('; ');
    final buffer = StringBuffer(
      'Work arrivals after $scheduledLabel: $lateArrivalCount of $totalWorkDays workdays',
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
