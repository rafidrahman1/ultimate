import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/results/derived_metrics_builder.dart';

DailySleepEntry _night(
  int day, {
  required int hours,
  required int minutes,
  required int bedH,
  required int bedM,
}) {
  final wakeDate = DateTime(2026, 5, day);
  return DailySleepEntry(
    wakeDate: wakeDate,
    session: SleepSummary(
      duration: Duration(hours: hours, minutes: minutes),
      startTime: DateTime(2026, 5, day - 1, bedH, bedM),
      endTime: DateTime(2026, 5, day, 7, 0),
    ),
  );
}

void main() {
  final period = AnalysisPeriod.forDataMonth(
    DateTime(2026, 5, 1),
    DateTime(2026, 5, 11),
  );

  test('builds derived metrics with month summary and anomaly candidates only', () {
    final text = buildDerivedMetrics(
      selection: AnalysisSourceSelection.all(),
      health: MonthlyHealthSummary(
        periodStart: DateTime(2026, 5, 1),
        periodEnd: DateTime(2026, 5, 31),
        dayCount: 31,
        dailySleep: [
          for (var day = 1; day <= 15; day++)
            _night(day, hours: 6, minutes: 30, bedH: 23, bedM: 30),
          _night(5, hours: 5, minutes: 42, bedH: 23, bedM: 30),
          _night(26, hours: 4, minutes: 13, bedH: 1, bedM: 30),
          _night(27, hours: 3, minutes: 32, bedH: 2, bedM: 18),
          _night(28, hours: 5, minutes: 7, bedH: 23, bedM: 54),
          _night(29, hours: 5, minutes: 45, bedH: 23, bedM: 30),
          _night(30, hours: 5, minutes: 44, bedH: 23, bedM: 35),
          _night(31, hours: 4, minutes: 49, bedH: 1, bedM: 10),
        ],
      ),
      expenses: ExpensesSummary(
        transactions: [
          CashewTransaction(
            account: 'Bank',
            amount: 35000,
            currency: 'BDT',
            date: DateTime(2026, 5, 1),
            isIncome: true,
            category: 'Cash In',
          ),
          CashewTransaction(
            account: 'Bank',
            amount: -2126.85,
            currency: 'BDT',
            date: DateTime(2026, 5, 4),
            isIncome: false,
            subcategory: 'Snacks',
          ),
          for (var i = 0; i < 5; i++)
            CashewTransaction(
              account: 'Bank',
              amount: -250,
              currency: 'BDT',
              date: DateTime(2026, 5, 10 + i),
              isIncome: false,
              subcategory: 'Snacks',
            ),
          CashewTransaction(
            account: 'Bank',
            amount: -6000,
            currency: 'BDT',
            date: DateTime(2026, 5, 18),
            isIncome: false,
            subcategory: 'Electronics',
            title: 'Leobog hi75',
          ),
        ],
      ),
      location: LocationSummary(
        activities: const [],
        placeVisits: [
          TimelinePlaceVisit(
            startTime: DateTime.parse('2026-05-05T10:35:00.000+06:00'),
            endTime: DateTime.parse('2026-05-05T18:00:00.000+06:00'),
            name: 'Work',
            semanticType: 'TYPE_WORK',
          ),
        ],
      ),
      calendar: const CalendarSummary(events: []),
      period: period,
      workHours: '10:30 AM to 6:00 PM',
    );

    expect(text, contains('Month: Active'));
    expect(text, contains('Sleep debt:'));
    expect(text, isNot(contains('Sleep Debt')));
    expect(text, isNot(contains('Expenses:')));
    expect(text, isNot(contains('Expense Concentration:')));
    expect(text, isNot(contains('Mobility:')));
    expect(text, isNot(contains('Sleep-Mobility Correlation')));
    expect(text, contains('Anomaly Candidates'));
    expect(text, contains('Severity:'));
    expect(text, contains('Recurrence:'));
    expect(text, contains('Cross-domain:'));
  });
}
