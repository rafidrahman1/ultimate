import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/results/anomaly_ranking.dart';

CashewTransaction _expense({
  required double amount,
  required DateTime date,
  String? subcategory,
}) {
  return CashewTransaction(
    account: 'Bank',
    amount: -amount,
    currency: 'BDT',
    date: date,
    isIncome: false,
    subcategory: subcategory,
  );
}

void main() {
  final outingEvent = MajorCalendarEvent(
    title: 'Wife outing',
    start: DateTime(2026, 6, 14, 18),
    end: DateTime(2026, 6, 14, 21),
    isHoliday: false,
  );

  ExpensesSummary eventLinkedRestaurantSummary() {
    return ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Bank',
          amount: 35000,
          currency: 'BDT',
          date: DateTime(2026, 6, 1),
          isIncome: true,
          category: 'Cash In',
        ),
        _expense(
          amount: 4000,
          date: DateTime(2026, 6, 14, 16, 45),
          subcategory: 'Restaurant',
        ),
        _expense(
          amount: 1000,
          date: DateTime(2026, 6, 14, 19, 30),
          subcategory: 'Restaurant',
        ),
      ],
    );
  }

  test('suppresses spending cluster when event-explained and below income cap', () {
    final summary = eventLinkedRestaurantSummary();
    final candidates = buildAnomalyCandidates(
      expenses: summary,
      calendarEvents: [outingEvent],
      monthlyIncomeBdt: '35000',
    );

    expect(
      candidates.any((c) => c.label.contains('spending cluster')),
      isFalse,
    );
  });

  test('keeps spending cluster when category exceeds 15% of monthly income', () {
    final summary = ExpensesSummary(
      transactions: [
        _expense(
          amount: 4000,
          date: DateTime(2026, 6, 14, 16, 45),
          subcategory: 'Restaurant',
        ),
        _expense(
          amount: 1000,
          date: DateTime(2026, 6, 14, 19, 30),
          subcategory: 'Restaurant',
        ),
      ],
    );
    final candidates = buildAnomalyCandidates(
      expenses: summary,
      calendarEvents: [outingEvent],
      monthlyIncomeBdt: '20000',
    );

    expect(
      candidates.any((c) => c.label == 'Restaurant spending cluster'),
      isTrue,
    );
  });

  test('keeps spending cluster when purchases are not all event-linked', () {
    final summary = ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Bank',
          amount: 35000,
          currency: 'BDT',
          date: DateTime(2026, 6, 1),
          isIncome: true,
          category: 'Cash In',
        ),
        _expense(
          amount: 4000,
          date: DateTime(2026, 6, 14, 16, 45),
          subcategory: 'Restaurant',
        ),
        _expense(
          amount: 1000,
          date: DateTime(2026, 6, 20),
          subcategory: 'Restaurant',
        ),
      ],
    );

    final candidates = buildAnomalyCandidates(
      expenses: summary,
      calendarEvents: [outingEvent],
      monthlyIncomeBdt: '35000',
    );

    expect(
      candidates.any((c) => c.label == 'Restaurant spending cluster'),
      isTrue,
    );
  });

  test('keeps spending cluster when budget is overrun', () {
    final summary = eventLinkedRestaurantSummary();
    final candidates = buildAnomalyCandidates(
      expenses: summary,
      calendarEvents: [outingEvent],
      monthlyIncomeBdt: '35000',
      monthlyBudgetBdt: 4000,
    );

    expect(candidates.any((c) => c.label == 'Budget overrun'), isTrue);
    expect(
      candidates.any((c) => c.label == 'Restaurant spending cluster'),
      isTrue,
    );
  });

  test('omits severity-0 candidates from ranked output', () {
    final candidates = buildAnomalyCandidates(
      expenses: ExpensesSummary(
        transactions: [
          _expense(amount: 50, date: DateTime(2026, 6, 1), subcategory: 'Snacks'),
          _expense(amount: 40, date: DateTime(2026, 6, 2), subcategory: 'Snacks'),
        ],
      ),
      monthlyIncomeBdt: '35000',
    );

    expect(candidates.every((candidate) => candidate.severity > 0), isTrue);
    expect(
      formatAnomalyCandidatesText(candidates),
      isNot(contains('- Severity: 0')),
    );
  });

  test('merges category purchase into spending cluster anomaly', () {
    final summary = ExpensesSummary(
      transactions: [
        _expense(
          amount: 6000,
          date: DateTime(2026, 6, 14, 16, 45),
          subcategory: 'Restaurant',
        ),
        _expense(
          amount: 1000,
          date: DateTime(2026, 6, 14, 19, 30),
          subcategory: 'Restaurant',
        ),
      ],
    );
    final candidates = buildAnomalyCandidates(
      expenses: summary,
      monthlyIncomeBdt: '20000',
    );

    expect(
      candidates.where((c) => c.label.toLowerCase().contains('restaurant')),
      hasLength(1),
    );
    expect(candidates.single.label, 'Restaurant spending cluster');
  });

  test('ranks sleep debt before attendance and spending cluster', () {
    final candidates = buildAnomalyCandidates(
      dailySleep: [
        for (var day = 1; day <= 8; day++)
          DailySleepEntry(
            wakeDate: DateTime(2026, 5, day),
            session: SleepSummary(
              duration: const Duration(hours: 5, minutes: 30),
              startTime: DateTime(2026, 5, day - 1, 23, 30),
              endTime: DateTime(2026, 5, day, 6, 30),
            ),
          ),
      ],
      expenses: ExpensesSummary(
        transactions: [
          _expense(
            amount: 4000,
            date: DateTime(2026, 6, 14, 16, 45),
            subcategory: 'Restaurant',
          ),
          _expense(
            amount: 1000,
            date: DateTime(2026, 6, 14, 19, 30),
            subcategory: 'Restaurant',
          ),
        ],
      ),
      calendarEvents: [outingEvent],
      workStats: WorkArrivalStats(
        workDays: [
          WorkDayArrival(
            date: DateTime(2026, 5, 12),
            arrivalTime: DateTime(2026, 5, 12, 10, 35),
            scheduledArrival: DateTime(2026, 5, 12, 10, 30),
          ),
        ],
        lateArrivals: [
          WorkDayArrival(
            date: DateTime(2026, 5, 12),
            arrivalTime: DateTime(2026, 5, 12, 10, 35),
            scheduledArrival: DateTime(2026, 5, 12, 10, 30),
          ),
        ],
        threshold: const WorkArrivalThreshold(hour: 10, minute: 25),
        workHours: '10:30 AM to 6:00 PM',
      ),
      monthlyIncomeBdt: '20000',
    );

    expect(candidates.length, greaterThanOrEqualTo(2));
    expect(candidates.first.label, 'Sleep debt accumulation');
    expect(candidates[1].label, 'Attendance degradation');
  });
}
