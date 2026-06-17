import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/results/analytics_pipeline_validation.dart';

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
  test('category share uses total spending as denominator', () {
    final summary = ExpensesSummary(
      transactions: [
        CashewTransaction(
          account: 'Bank',
          amount: 35000,
          currency: 'BDT',
          date: DateTime(2026, 5, 1),
          isIncome: true,
          category: 'Cash In',
        ),
        _expense(amount: 3350, date: DateTime(2026, 5, 2), subcategory: 'Restaurant'),
        _expense(amount: 2683, date: DateTime(2026, 5, 3), subcategory: 'Miscellaneous'),
        _expense(amount: 1759.85, date: DateTime(2026, 5, 4), subcategory: 'Fuel'),
        _expense(amount: 2764.65, date: DateTime(2026, 5, 5), subcategory: 'Snacks'),
      ],
    );

    final text = buildExpensePromptText(summary);

    expect(text, contains('1. Restaurant'));
    expect(text, contains('- Total: 3,350.00 (31.7% of spending)'));
    expect(text, contains('2. Snacks'));
    expect(text, contains('- Total: 2,764.65 (26.2% of spending)'));
    expect(text, contains('3. Miscellaneous'));
    expect(text, contains('- Total: 2,683.00 (25.4% of spending)'));
    expect(text, contains('4. Fuel'));
    expect(text, contains('- Total: 1,759.85 (16.7% of spending)'));
    expect(
      text,
      contains('- Top category share (of spending): 31.7%'),
    );
    expect(text, contains('- Income remaining: 24,442.50 BDT'));
  });

  test('validateWorkAttendance detects count and record mismatches', () {
    final stats = WorkArrivalStats(
      workDays: const [],
      lateArrivals: const [],
      threshold: const WorkArrivalThreshold(hour: 10, minute: 25),
      workHours: '10:30 AM to 6:00 PM',
    );

    expect(
      AnalyticsPipelineValidation.validateWorkAttendance(stats),
      isEmpty,
    );
  });

  test('validateWorkAttendance flags on-time arrivals in late list', () {
    final scheduled = DateTime(2026, 5, 10, 10, 30);
    final stats = WorkArrivalStats(
      workDays: [
        WorkDayArrival(
          date: DateTime(2026, 5, 10),
          arrivalTime: DateTime(2026, 5, 10, 10, 30),
          scheduledArrival: scheduled,
        ),
      ],
      lateArrivals: [
        WorkDayArrival(
          date: DateTime(2026, 5, 10),
          arrivalTime: DateTime(2026, 5, 10, 10, 30),
          scheduledArrival: scheduled,
        ),
      ],
      threshold: const WorkArrivalThreshold(hour: 10, minute: 25),
      workHours: '10:30 AM to 6:00 PM',
    );

    final warnings = AnalyticsPipelineValidation.validateWorkAttendance(stats);
    expect(warnings, isNotEmpty);
    expect(warnings.first, contains('Non-late arrival'));
  });
}
