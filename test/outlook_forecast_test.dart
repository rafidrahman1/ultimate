import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/analysis/expense_insights.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/forecasts/outlook/outlook_forecast.dart';
import 'package:personal/features/forecasts/outlook/recurring_forecast.dart';

CashewTransaction salary(DateTime date, [double amount = 50000]) =>
    CashewTransaction(
      account: 'Bank',
      amount: amount,
      currency: 'BDT',
      date: date,
      isIncome: true,
      category: 'Cash in',
      subcategory: 'Salary',
    );

MonthProjection projection({
  required double spent,
  required double projected,
  int daysElapsed = 10,
}) => MonthProjection(
  spentSoFar: spent,
  projected: projected,
  typicalMonth: 30000,
  daysElapsed: daysElapsed,
  daysInMonth: 30,
);

void main() {
  group('bank days', () {
    // 2026-11-13 is a Friday.
    test('Friday and Saturday move to Sunday or back to Thursday', () {
      expect(DateTime(2026, 11, 13).weekday, DateTime.friday);
      expect(nextBankDay(DateTime(2026, 11, 13)), DateTime(2026, 11, 15));
      expect(nextBankDay(DateTime(2026, 11, 14)), DateTime(2026, 11, 15));
      expect(previousBankDay(DateTime(2026, 11, 13)), DateTime(2026, 11, 12));
      expect(previousBankDay(DateTime(2026, 11, 14)), DateTime(2026, 11, 12));
    });

    test('a working day is left alone', () {
      expect(nextBankDay(DateTime(2026, 11, 11, 9)), DateTime(2026, 11, 11));
      expect(previousBankDay(DateTime(2026, 11, 15)), DateTime(2026, 11, 15));
    });
  });

  group('forecastBudgetRunout', () {
    final now = DateTime(2026, 11, 10, 15);

    test('null without a budget or projection', () {
      expect(
        forecastBudgetRunout(
          budget: null,
          projection: projection(spent: 1, projected: 2),
          now: now,
        ),
        isNull,
      );
      expect(
        forecastBudgetRunout(budget: 1000, projection: null, now: now),
        isNull,
      );
    });

    test('already over budget runs out today', () {
      final o = forecastBudgetRunout(
        budget: 1000,
        projection: projection(spent: 1200, projected: 3000),
        now: now,
      )!;
      expect(o.isOver, isTrue);
      expect(o.runoutDate, DateTime(2026, 11, 10));
    });

    test('runs out on the day the remaining budget is used up', () {
      // 20 days left, 2000 more to spend: 100 a day. 500 left lasts 5 days.
      final o = forecastBudgetRunout(
        budget: 1500,
        projection: projection(spent: 1000, projected: 3000),
        now: now,
      )!;
      expect(o.runoutDate, DateTime(2026, 11, 15));
      expect(o.left, 500);
      expect(o.lastsMonth, isFalse);
    });

    test('lasts the month when the projection stays under budget', () {
      final o = forecastBudgetRunout(
        budget: 5000,
        projection: projection(spent: 1000, projected: 3000),
        now: now,
      )!;
      expect(o.runoutDate, isNull);
      expect(o.lastsMonth, isTrue);
    });
  });

  group('forecastPayday', () {
    test('null without regular salary', () {
      expect(
        forecastPayday(
          [salary(DateTime(2026, 10, 1))],
          projection: null,
          upcoming: const [],
          now: DateTime(2026, 11, 10),
        ),
        isNull,
      );
    });

    test('other income is not treated as salary', () {
      final gifts = [
        for (var m = 6; m <= 10; m++)
          CashewTransaction(
            account: 'Bank',
            amount: 50000,
            currency: 'BDT',
            date: DateTime(2026, m, 1),
            isIncome: true,
            category: 'Cash in',
            subcategory: 'Gift',
          ),
      ];
      expect(
        forecastPayday(
          gifts,
          projection: null,
          upcoming: const [],
          now: DateTime(2026, 11, 10),
        ),
        isNull,
      );
    });

    test('drifting monthly pay is found and never lands on Fri/Sat', () {
      // Pay day wanders between the 1st and the 9th, so the gaps are uneven.
      final pay = [
        salary(DateTime(2026, 6, 1)),
        salary(DateTime(2026, 7, 9)),
        salary(DateTime(2026, 8, 2)),
        salary(DateTime(2026, 9, 8)),
        salary(DateTime(2026, 10, 1)),
      ];
      final now = DateTime(2026, 10, 20);
      final outlook = forecastPayday(
        pay,
        projection: projection(spent: 0, projected: 30000),
        upcoming: [
          UpcomingCharge(
            label: 'Rent',
            cadence: 'monthly',
            amount: 12000,
            expectedDate: DateTime(2026, 10, 25),
            lastDate: DateTime(2026, 9, 25),
            count: 4,
            declared: true,
          ),
          UpcomingCharge(
            label: 'Later',
            cadence: 'monthly',
            amount: 999,
            expectedDate: DateTime(2026, 12, 25),
            lastDate: DateTime(2026, 11, 25),
            count: 4,
            declared: true,
          ),
        ],
        now: now,
      );
      expect(outlook, isNotNull);
      final o = outlook!;
      expect(o.amount, 50000);
      expect(o.expectedDate.isAfter(now), isTrue);
      expect(o.expectedDate.weekday, isNot(DateTime.friday));
      expect(o.expectedDate.weekday, isNot(DateTime.saturday));
      expect(o.daysUntil, o.expectedDate.difference(now).inDays);
      // Only the bill due before payday counts.
      expect(o.billsBefore, 12000);
      // 30000 a month over 30 days is 1000 a day.
      expect(o.expectedSpend, closeTo(1000.0 * o.daysUntil, 0.01));
    });

    test('pay that lapsed more than three weeks ago is dropped', () {
      final pay = [
        salary(DateTime(2026, 3, 1)),
        salary(DateTime(2026, 4, 9)),
        salary(DateTime(2026, 5, 2)),
      ];
      expect(
        forecastPayday(
          pay,
          projection: null,
          upcoming: const [],
          now: DateTime(2026, 8, 20),
        ),
        isNull,
      );
    });
  });
}
