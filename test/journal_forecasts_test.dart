import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecasts_journal.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/journal/data/journal_models.dart';
import 'package:personal/features/screen_time/data/phone_habits_models.dart';

void main() {
  final now = DateTime(2026, 10, 20, 12);
  final today = DateTime(2026, 10, 20);
  DateTime ago(int back) => DateTime(2026, 10, 20 - back);

  DailySleepEntry night(int back, double hours) {
    final end = ago(back).add(const Duration(hours: 7));
    return DailySleepEntry(
      wakeDate: ago(back),
      session: SleepSummary(
        duration: Duration(minutes: (hours * 60).round()),
        startTime: end.subtract(Duration(minutes: (hours * 60).round())),
        endTime: end,
      ),
    );
  }

  group('journal model', () {
    test('a coffee after midnight belongs to the evening before', () {
      final journal = Journal(
        intakes: [
          IntakeEvent(DateTime(2026, 10, 19, 15), IntakeKind.caffeine),
          IntakeEvent(DateTime(2026, 10, 20, 1), IntakeKind.caffeine),
          IntakeEvent(DateTime(2026, 10, 20, 9), IntakeKind.caffeine),
        ],
      );
      expect(habitDayOf(DateTime(2026, 10, 20, 1)), DateTime(2026, 10, 19));
      expect(journal.lastMinutesByDay(IntakeKind.caffeine), {
        DateTime(2026, 10, 19): 25 * 60,
        today: 9 * 60,
      });
      expect(
        journal.countByDay(IntakeKind.caffeine)[DateTime(2026, 10, 19)],
        2,
      );
      expect(journal.lastMinutesByDay(IntakeKind.meal), isEmpty);
    });

    test('round-trips through JSON and drops malformed rows', () {
      final journal = Journal(
        checkIns: [DayCheckIn(day: today, mood: 4, energy: 3, stress: 2)],
        intakes: [IntakeEvent(DateTime(2026, 10, 20, 8), IntakeKind.meal)],
      );
      final json = journal.toJson();
      (json['checkIns'] as List).add({
        'd': '2026-10-21',
        'm': 9,
        'e': 1,
        's': 1,
      });
      (json['intakes'] as List).add({'t': 'soon', 'k': 'meal'});
      final back = Journal.fromJson(json);
      expect(back.checkIns, hasLength(1));
      expect(back.checkInOn(today)!.energy, 3);
      expect(back.intakes.single.kind, IntakeKind.meal);
    });
  });

  group('phone habits', () {
    PhoneDay day(int back, int pickups, {bool complete = true}) => PhoneDay(
      day: ago(back),
      pickups: pickups,
      lastUse: ago(back).add(const Duration(hours: 23)),
      complete: complete,
    );

    test('merging keeps saved days Android has since forgotten', () {
      final saved = PhoneHabits([
        day(9, 80),
        day(2, 70),
        day(1, 30, complete: false),
      ]);
      // A later read: day 9 aged out, day 2 lost half its events, day 1 ended.
      final fresh = PhoneHabits([
        day(2, 35),
        day(1, 90),
        day(0, 12, complete: false),
      ]);
      final merged = saved.mergedWith(fresh);
      expect(merged.days.map((d) => d.pickups), [80, 70, 90, 12]);
      expect(merged.completeDays, hasLength(3));
    });

    test('reads channel rows and reports use past midnight above 24h', () {
      final habits = PhoneHabits.fromRows([
        {
          'day': today.millisecondsSinceEpoch,
          'pickups': 50,
          'firstMs': DateTime(2026, 10, 20, 7).millisecondsSinceEpoch,
          'lastMs': DateTime(2026, 10, 21, 1).millisecondsSinceEpoch,
          'complete': true,
        },
        {'day': 'bad'},
      ]);
      expect(habits.days.single.firstUseMinutes, 7 * 60);
      expect(habits.days.single.lastUseMinutes, 25 * 60);
      expect(PhoneHabits.fromJson(habits.toJson()).days.single.pickups, 50);
    });
  });

  group('energy', () {
    test('needs seven check-ins', () {
      final journal = Journal(
        checkIns: [
          for (var b = 1; b <= 6; b++)
            DayCheckIn(day: ago(b), mood: 3, energy: 3, stress: 3),
        ],
      );
      expect(forecastEnergy(LifeInputs(now: now, journal: journal)), isNull);
    });

    test('reports the recent average when no habit explains it', () {
      final journal = Journal(
        checkIns: [
          for (var b = 1; b <= 8; b++)
            DayCheckIn(day: ago(b), mood: 3, energy: 4, stress: 2),
        ],
      );
      final f = forecastEnergy(LifeInputs(now: now, journal: journal))!;
      expect(f.headline, '4.0 / 5');
      expect(f.detail, contains('No single habit'));
    });

    test('predicts today from sleep when energy follows it', () {
      // Energy rises with sleep: 5h -> 2, 6h -> 3, 7h -> 4, 8h -> 5.
      final hours = [5.0, 6.0, 7.0, 8.0, 5.0, 6.0, 7.0, 8.0, 6.0, 7.0];
      final inputs = LifeInputs(
        now: now,
        nights: [
          night(0, 5),
          for (var b = 1; b <= hours.length; b++) night(b, hours[b - 1]),
        ],
        journal: Journal(
          checkIns: [
            for (var b = 1; b <= hours.length; b++)
              DayCheckIn(
                day: ago(b),
                mood: 3,
                energy: hours[b - 1].round() - 3,
                stress: 3,
              ),
          ],
        ),
      );
      final f = forecastEnergy(inputs)!;
      expect(f.headline, '~2.0 / 5');
      expect(f.detail, contains('sleep the night before'));
      expect(f.attention, isTrue);
      expect(f.rawData, contains('energy 1-5'));
    });
  });

  group('caffeine cut-off', () {
    LifeInputs inputs(double Function(int hour) sleepFor) {
      // Last coffee alternates between 13:00 and 18:00 over ten days.
      final hoursOfDay = [for (var b = 1; b <= 10; b++) b.isEven ? 13 : 18];
      return LifeInputs(
        now: now,
        nights: [
          // The night after day `b` ends on day `b - 1`.
          for (var b = 1; b <= 10; b++)
            night(b - 1, sleepFor(hoursOfDay[b - 1])),
        ],
        journal: Journal(
          intakes: [
            for (var b = 1; b <= 10; b++)
              IntakeEvent(
                ago(b).add(Duration(hours: hoursOfDay[b - 1])),
                IntakeKind.caffeine,
              ),
          ],
        ),
      );
    }

    test('needs eight logged days', () {
      final journal = Journal(
        intakes: [
          IntakeEvent(
            ago(1).add(const Duration(hours: 15)),
            IntakeKind.caffeine,
          ),
        ],
      );
      expect(
        forecastCaffeineCutoff(LifeInputs(now: now, journal: journal)),
        isNull,
      );
    });

    test('names a cut-off when late coffee shortens sleep', () {
      final f = forecastCaffeineCutoff(inputs((h) => h == 13 ? 7.5 : 6.0))!;
      expect(f.kind, LifeForecastKind.caffeine);
      expect(f.headline, 'By 13:00');
      // 1.5h less sleep across 5 hours is 18 minutes an hour.
      expect(f.detail, contains('18 minutes less'));
    });

    test('says so when timing makes no difference', () {
      final f = forecastCaffeineCutoff(inputs((_) => 7.0))!;
      expect(f.headline, 'No clear effect');
      expect(forecastLateMeal(inputs((_) => 7.0)), isNull);
    });
  });

  group('phone-down time', () {
    PhoneDay day(int back, int lastMinutes) => PhoneDay(
      day: ago(back),
      pickups: 60,
      lastUse: ago(back).add(Duration(minutes: lastMinutes)),
    );

    test('needs a week of finished days', () {
      final phone = PhoneHabits([
        for (var b = 1; b <= 6; b++) day(b, 23 * 60),
        PhoneDay(day: today, pickups: 5, complete: false),
      ]);
      expect(forecastPhoneDown(LifeInputs(now: now, phone: phone)), isNull);
    });

    test('flags a drift to later nights', () {
      final phone = PhoneHabits([
        for (var b = 4; b <= 10; b++) day(b, 23 * 60),
        for (var b = 1; b <= 3; b++) day(b, 24 * 60 + 30),
      ]);
      final f = forecastPhoneDown(LifeInputs(now: now, phone: phone))!;
      expect(f.headline, '00:30');
      expect(f.detail, contains('90 minutes later than your usual 23:00'));
      expect(f.detail, contains('60 times a day'));
      expect(f.attention, isTrue);
    });
  });

  test('joined rows carry phone, coffee and check-in columns', () {
    final rows = patternRows(
      LifeInputs(
        now: now,
        journal: Journal(
          checkIns: [DayCheckIn(day: ago(1), mood: 4, energy: 2, stress: 5)],
          intakes: [
            IntakeEvent(
              ago(1).add(const Duration(hours: 16)),
              IntakeKind.caffeine,
            ),
          ],
        ),
        phone: PhoneHabits([
          PhoneDay(
            day: ago(1),
            pickups: 77,
            lastUse: ago(1).add(const Duration(hours: 23, minutes: 30)),
          ),
        ]),
      ),
    );
    expect(rows, contains('| 77 | 23:30 | 1 | 16:00 | - | 4 | 2 | 5'));
  });
}
