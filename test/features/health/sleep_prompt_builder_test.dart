import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/health/health_summary.dart';

DailySleepEntry _night(
  int day, {
  required int hours,
  required int minutes,
  required int bedH,
  required int bedM,
  required int wakeH,
  required int wakeM,
}) {
  final wakeDate = DateTime(2026, 5, day);
  final bedtime = DateTime(2026, 5, day - 1, bedH, bedM);
  final wake = DateTime(2026, 5, day, wakeH, wakeM);
  return DailySleepEntry(
    wakeDate: wakeDate,
    session: SleepSummary(
      duration: Duration(hours: hours, minutes: minutes),
      startTime: bedtime,
      endTime: wake,
    ),
  );
}

MonthlyHealthSummary _summary(List<DailySleepEntry> sleep) {
  return MonthlyHealthSummary(
    periodStart: DateTime(2026, 5, 1),
    periodEnd: DateTime(2026, 5, 31, 23, 59),
    dailySleep: sleep,
    dayCount: 31,
  );
}

void main() {
  test('formats structured sleep summary for analysis prompt', () {
    final text = _summary([
      _night(7, hours: 5, minutes: 30, bedH: 23, bedM: 30, wakeH: 7, wakeM: 0),
      _night(8, hours: 5, minutes: 15, bedH: 23, bedM: 45, wakeH: 7, wakeM: 0),
      _night(23, hours: 5, minutes: 45, bedH: 23, bedM: 30, wakeH: 7, wakeM: 15),
      _night(24, hours: 5, minutes: 25, bedH: 23, bedM: 40, wakeH: 7, wakeM: 5),
      _night(25, hours: 6, minutes: 21, bedH: 23, bedM: 20, wakeH: 7, wakeM: 41),
      _night(26, hours: 4, minutes: 13, bedH: 1, bedM: 30, wakeH: 7, wakeM: 43),
      _night(27, hours: 3, minutes: 32, bedH: 2, bedM: 18, wakeH: 8, wakeM: 9),
      _night(28, hours: 5, minutes: 7, bedH: 23, bedM: 54, wakeH: 5, wakeM: 47),
      _night(29, hours: 5, minutes: 45, bedH: 23, bedM: 30, wakeH: 7, wakeM: 15),
      _night(30, hours: 5, minutes: 44, bedH: 23, bedM: 35, wakeH: 7, wakeM: 19),
      _night(31, hours: 4, minutes: 49, bedH: 1, bedM: 10, wakeH: 7, wakeM: 0),
      _night(16, hours: 8, minutes: 6, bedH: 23, bedM: 25, wakeH: 8, wakeM: 24),
    ]).toSleepPromptText();

    expect(text, startsWith('Sleep Summary'));
    expect(text, contains('Typical:'));
    expect(text, contains('Average duration:'));
    expect(text, contains('Average bedtime:'));
    expect(text, contains('Average wake time:'));
    expect(text, contains('Monthly Metrics:'));
    expect(text, contains('Short sleep nights (<6h):'));
    expect(text, contains('Very short sleep nights (<4h):'));
    expect(text, contains('Late bedtimes (>02:00):'));
    expect(text, contains('Early wakes (<06:00):'));
    expect(text, contains('Clusters:'));
    expect(text, contains('7–8 May: 2 consecutive short sleep nights'));
    expect(text, contains('23–31 May: 8 short sleep nights in 9 days'));
    expect(text, contains('26–31 May: 6 consecutive short sleep nights'));
    expect(text, contains('Worst Night:'));
    expect(text, contains('- 27 May'));
    expect(text, contains('Sleep: 3h 32m'));
    expect(text, contains('Bedtime: 02:18'));
    expect(text, contains('Wake: 08:09'));
    expect(text, contains('Daily Records:'));
    expect(text, contains('- 23 May: 5h45m'));
    expect(text, contains('- 27 May: 3h32m'));
    expect(text, contains('- 31 May: 4h49m'));
  });

  test('returns empty text when no sleep nights are tracked', () {
    expect(
      _summary(const []).toSleepPromptText(),
      isEmpty,
    );
  });

  test('omits clusters when there are no short sleep patterns', () {
    final text = _summary([
      _night(3, hours: 7, minutes: 23, bedH: 22, bedM: 7, wakeH: 9, wakeM: 18),
      _night(4, hours: 8, minutes: 0, bedH: 23, bedM: 0, wakeH: 7, wakeM: 0),
    ]).toSleepPromptText();

    expect(text, isNot(contains('Clusters:')));
    expect(text, contains('Short sleep nights (<6h): 0'));
    expect(text, contains('Daily Records:'));
  });
}
