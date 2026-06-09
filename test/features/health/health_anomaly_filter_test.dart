import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/health/health_anomaly_filter.dart';
import 'package:personal/features/health/health_summary.dart';

MonthlyHealthSummary _summary({
  required List<DailySleepEntry> sleep,
  Map<DateTime, int>? dailySteps,
  double avgSteps = 3182,
  int dayCount = 31,
}) {
  return MonthlyHealthSummary(
    periodStart: DateTime(2026, 5, 1),
    periodEnd: DateTime(2026, 5, 31, 23, 59),
    avgStepsPerDay: avgSteps,
    dailySleep: sleep,
    dailySteps: dailySteps ?? const {},
    dayCount: dayCount,
  );
}

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

void main() {
  const filter = HealthAnomalyFilter();

  test('flags short sleep, very short sleep, late bedtime, and early wake', () {
    final report = filter.analyze(
      _summary(
        sleep: [
          _night(27, hours: 3, minutes: 32, bedH: 2, bedM: 18, wakeH: 8, wakeM: 9),
          _night(28, hours: 5, minutes: 7, bedH: 23, bedM: 54, wakeH: 5, wakeM: 47),
          _night(3, hours: 7, minutes: 23, bedH: 22, bedM: 7, wakeH: 9, wakeM: 18),
        ],
      ),
    );

    expect(report.sleepAnomalies, hasLength(2));

    final may27 = report.sleepAnomalies.first;
    expect(may27.entry.wakeDate.day, 27);
    expect(
      may27.reasons,
      containsAll(['very short sleep (<4h)', 'late bedtime (after 02:00)']),
    );

    final may28 = report.sleepAnomalies[1];
    expect(may28.reasons, contains('early wake (before 06:00)'));
    expect(may28.reasons, contains('short sleep (<6h)'));
  });

  test('does not flag typical 7h night with normal schedule', () {
    final report = filter.analyze(
      _summary(
        sleep: [
          _night(3, hours: 7, minutes: 23, bedH: 22, bedM: 7, wakeH: 9, wakeM: 18),
          _night(4, hours: 6, minutes: 57, bedH: 23, bedM: 56, wakeH: 8, wakeM: 45),
        ],
      ),
    );

    expect(report.sleepAnomalies, isEmpty);
  });

  test('toPromptText always includes steps average only', () {
    final dailySteps = <DateTime, int>{
      for (var day = 1; day <= 31; day++)
        DateTime(2026, 5, day): day == 15 ? 800 : 3200,
    };

    final text = _summary(
      sleep: const [],
      dailySteps: dailySteps,
      avgSteps: 3182,
    ).toAnalysisPromptText();

    expect(text, contains('Steps: 3182 avg per day (31 days)'));
    expect(text, isNot(contains('Steps (by day)')));
    expect(text, isNot(contains('Steps (period)')));
    expect(text, isNot(contains('800 steps')));
  });

  test('toPromptText omits normal nights and lists only sleep anomalies', () {
    final summary = _summary(
      sleep: [
        _night(3, hours: 7, minutes: 23, bedH: 22, bedM: 7, wakeH: 9, wakeM: 18),
        _night(27, hours: 3, minutes: 32, bedH: 2, bedM: 18, wakeH: 8, wakeM: 9),
      ],
      dailySteps: {DateTime(2026, 5, 1): 3200},
    );

    final text = summary.toAnalysisPromptText();

    expect(text, contains('Steps: 3182 avg per day'));
    expect(text, contains('Sleep (1 typical nights): 7h 23m avg'));
    expect(text, contains('bedtime 22:07 avg'));
    expect(text, contains('wake 09:18 avg'));
    expect(text, contains('27 May 2026'));
    expect(text, isNot(contains('3 May 2026')));
    expect(text, contains('very short sleep'));
  });

  test('toPromptText reports no sleep anomalies when all nights are typical', () {
    final summary = _summary(
      sleep: [
        _night(16, hours: 8, minutes: 6, bedH: 23, bedM: 25, wakeH: 8, wakeM: 24),
      ],
      dailySteps: {DateTime(2026, 5, 16): 9000},
      avgSteps: 9000,
    );

    final text = summary.toAnalysisPromptText();

    expect(text, contains('Steps: 9000 avg per day'));
    expect(text, contains('Sleep (1 typical nights): 8h 6m avg'));
    expect(text, contains('bedtime 23:25 avg'));
    expect(text, contains('wake 08:24 avg'));
    expect(text, contains('Sleep anomalies: none detected'));
    expect(text, isNot(contains('Sleep anomalies (by wake day)')));
  });

  test('toPromptText averages typical nights across multiple non-anomaly days', () {
    final summary = _summary(
      sleep: [
        _night(3, hours: 7, minutes: 23, bedH: 22, bedM: 7, wakeH: 9, wakeM: 18),
        _night(4, hours: 6, minutes: 57, bedH: 23, bedM: 56, wakeH: 8, wakeM: 45),
        _night(27, hours: 3, minutes: 32, bedH: 2, bedM: 18, wakeH: 8, wakeM: 9),
      ],
    );

    final text = summary.toAnalysisPromptText();

    expect(text, contains('Sleep (2 typical nights): 7h 10m avg'));
    expect(text, contains('bedtime 23:02 avg'));
    expect(text, contains('wake 09:02 avg'));
  });
}
