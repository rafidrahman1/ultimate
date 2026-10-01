import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';

TimelinePlaceVisit _work(DateTime start) => TimelinePlaceVisit(
  startTime: start,
  endTime: start.add(const Duration(hours: 8)),
  name: 'Office',
  semanticType: 'TYPE_WORK',
);

void main() {
  test('uses the first arrival per day and flags late days', () {
    final stats = WorkArrivalStats.analyze(
      placeVisits: [
        _work(DateTime(2026, 9, 1, 8, 55)), // on time
        _work(DateTime(2026, 9, 2, 9, 20)), // 20 min late
        _work(DateTime(2026, 9, 2, 13, 0)), // later visit same day ignored
        TimelinePlaceVisit(
          startTime: DateTime(2026, 9, 3, 11),
          endTime: DateTime(2026, 9, 3, 12),
          name: 'Cafe',
        ),
      ],
      workHours: '9:00 AM to 5:00 PM',
    );

    expect(stats.totalWorkDays, 2);
    expect(stats.lateArrivalCount, 1);
    expect(stats.lateArrivals.single.delayMinutes, 20);
  });

  test('no work hours means no lateness judgement', () {
    final stats = WorkArrivalStats.analyze(
      placeVisits: [_work(DateTime(2026, 9, 1, 11))],
    );
    expect(stats.totalWorkDays, 1);
    expect(stats.lateArrivalCount, 0);
  });

  test('late threshold sits 5 minutes before the start time', () {
    final threshold = lateArrivalThresholdFromWorkHours('9:00 AM to 5:00 PM');
    expect(threshold?.label, '08:55');
  });
}
