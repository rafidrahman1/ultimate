import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';

void main() {
  const workAddress = 'BRAC University, 66 Mohakhali, Dhaka';
  const workHours = '10:30 AM to 6:00 PM';

  test('lateArrivalThresholdFromWorkHours is 5 minutes before work start', () {
    final threshold = lateArrivalThresholdFromWorkHours(workHours);
    expect(threshold, isNotNull);
    expect(threshold!.label, '10:25');
  });

  test('effective office entry adds parking after target and fast clock offset', () {
    const threshold = WorkArrivalThreshold(hour: 10, minute: 25);

    expect(
      effectiveOfficeClockEntryMinutes(
        DateTime(2026, 5, 12, 10, 25),
        targetThreshold: threshold,
      ),
      10 * 60 + 27,
    );
    expect(
      effectiveOfficeClockEntryMinutes(
        DateTime(2026, 5, 12, 10, 26),
        targetThreshold: threshold,
      ),
      10 * 60 + 31,
    );
  });

  test('isWorkPlaceVisit matches TYPE_WORK semantic type', () {
    expect(
      isWorkPlaceVisit(
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-10T03:00:00.000Z'),
          endTime: DateTime.parse('2026-05-10T11:00:00.000Z'),
          name: 'Unknown place',
          semanticType: 'TYPE_WORK',
        ),
        '',
      ),
      isTrue,
    );
  });

  test('isWorkPlaceVisit matches labeled Work and address tokens', () {
    expect(
      isWorkPlaceVisit(
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-10T03:00:00.000Z'),
          endTime: DateTime.parse('2026-05-10T11:00:00.000Z'),
          name: 'Work',
        ),
        workAddress,
      ),
      isTrue,
    );
    expect(
      isWorkPlaceVisit(
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-10T03:00:00.000Z'),
          endTime: DateTime.parse('2026-05-10T11:00:00.000Z'),
          name: 'BRAC University',
          address: '66 Mohakhali, Dhaka 1212',
        ),
        workAddress,
      ),
      isTrue,
    );
    expect(
      isWorkPlaceVisit(
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-10T03:00:00.000Z'),
          endTime: DateTime.parse('2026-05-10T11:00:00.000Z'),
          name: 'Home',
          address: 'Gulshan',
        ),
        workAddress,
      ),
      isFalse,
    );
  });

  test('counts TYPE_WORK visits without late threshold when work hours missing', () {
    final stats = WorkArrivalStats.analyze(
      placeVisits: [
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-11T10:30:00.000+06:00'),
          endTime: DateTime.parse('2026-05-11T18:00:00.000+06:00'),
          name: 'Work',
          semanticType: 'TYPE_WORK',
        ),
      ],
    );

    expect(stats.totalWorkDays, 1);
    expect(stats.hasLateThreshold, isFalse);
    expect(stats.lateArrivalCount, 0);
  });

  test('counts first work arrival per day using office entry model', () {
    final stats = WorkArrivalStats.analyze(
      workAddress: workAddress,
      workHours: workHours,
      placeVisits: [
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-10T04:20:00.000+06:00'),
          endTime: DateTime.parse('2026-05-10T12:00:00.000+06:00'),
          name: 'Work',
        ),
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-11T10:30:00.000+06:00'),
          endTime: DateTime.parse('2026-05-11T18:00:00.000+06:00'),
          name: 'Work',
        ),
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-12T10:25:00.000+06:00'),
          endTime: DateTime.parse('2026-05-12T18:00:00.000+06:00'),
          name: 'Work',
        ),
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-13T10:31:00.000+06:00'),
          endTime: DateTime.parse('2026-05-13T18:00:00.000+06:00'),
          name: 'Work',
        ),
        TimelinePlaceVisit(
          startTime: DateTime.parse('2026-05-13T14:00:00.000+06:00'),
          endTime: DateTime.parse('2026-05-13T15:00:00.000+06:00'),
          name: 'Work',
        ),
      ],
    );

    expect(stats.thresholdLabel, '10:25');
    expect(stats.scheduledArrivalLabel, '10:30 AM');
    expect(stats.totalWorkDays, 4);
    expect(stats.lateArrivalCount, 2);
    expect(
      stats.lateArrivals.map((day) => day.date.day).toList(),
      [11, 13],
    );
    expect(stats.lateArrivals.first.delayMinutes, 5);
    expect(stats.lateArrivals.last.delayMinutes, 6);
    expect(stats.toPromptLine(), contains('2 of 4 workdays'));
    expect(stats.toPromptLine(), contains('target 10:25'));
  });
}
