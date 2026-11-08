import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecasts_ahead.dart';
import 'package:personal/features/health/data/health_summary.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);
  final today = DateTime(2026, 10, 20);

  DailySleepEntry night(int back, double hours) {
    final wake = today.subtract(Duration(days: back));
    final end = wake.add(const Duration(hours: 7));
    return DailySleepEntry(
      wakeDate: wake,
      session: SleepSummary(
        duration: Duration(minutes: (hours * 60).round()),
        startTime: end.subtract(Duration(minutes: (hours * 60).round())),
        endTime: end,
      ),
    );
  }

  test('sleep debt needs four nights and suggests a bedtime', () {
    expect(
      forecastSleepDebt(LifeInputs(now: now, nights: [night(1, 5)])),
      isNull,
    );
    final f = forecastSleepDebt(
      LifeInputs(now: now, nights: [for (var b = 1; b <= 6; b++) night(b, 5)]),
    );
    expect(f, isNotNull);
    expect(f!.headline, contains('short'));
    expect(f.detail, contains('in bed by'));
  });

  test('sleep debt reports on target when sleep meets the goal', () {
    final f = forecastSleepDebt(
      LifeInputs(
        now: now,
        nights: [for (var b = 1; b <= 6; b++) night(b, 7.5)],
      ),
    );
    expect(f!.headline, 'On target');
  });

  test('week ahead needs events and flags a heavier week', () {
    expect(forecastWeekAhead(LifeInputs(now: now)), isNull);
    CalendarEvent meeting(DateTime d, int hours) => CalendarEvent(
      title: 'Meeting',
      start: d.add(const Duration(hours: 9)),
      end: d.add(Duration(hours: 9 + hours)),
      allDay: false,
    );
    final events = [
      for (var w = 1; w <= 3; w++)
        meeting(today.subtract(Duration(days: w * 7)), 2),
      for (var d = 0; d < 5; d++) meeting(today.add(Duration(days: d)), 4),
    ];
    final f = forecastWeekAhead(LifeInputs(now: now, events: events));
    expect(f, isNotNull);
    expect(f!.headline, contains('20h'));
    expect(f.attention, isTrue);
  });

  test('week spend needs a month of history', () {
    expect(
      forecastWeekSpend(LifeInputs(now: now, dailySpend: {today: 100})),
      isNull,
    );
    final spend = {
      for (var b = 1; b <= 40; b++) today.subtract(Duration(days: b)): 100.0,
    };
    final f = forecastWeekSpend(LifeInputs(now: now, dailySpend: spend));
    expect(f, isNotNull);
    expect(f!.kind, LifeForecastKind.weekSpend);
    expect(f.headline, contains('700'));
  });
}
