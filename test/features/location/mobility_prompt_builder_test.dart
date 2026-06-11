import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';

void main() {
  const workAddress = 'BRAC University, 66 Mohakhali, Dhaka';
  const workHours = '10:30 AM to 6:00 PM';

  test('formats structured mobility summary for analysis prompt', () {
    final text = buildMobilityPromptText(
      summary: LocationSummary(
        activities: [
          TimelineActivity(
            startTime: DateTime.parse('2026-05-10T08:00:00.000+06:00'),
            endTime: DateTime.parse('2026-05-10T10:50:00.000+06:00'),
            type: 'MOTORCYCLING',
            distanceMeters: 478220,
          ),
          TimelineActivity(
            startTime: DateTime.parse('2026-05-11T12:00:00.000+06:00'),
            endTime: DateTime.parse('2026-05-11T12:15:00.000+06:00'),
            type: 'WALKING',
            distanceMeters: 1000,
          ),
        ],
        placeVisits: [
          for (final day in [5, 6, 7, 8, 9, 10, 11, 13, 14, 15, 16])
            TimelinePlaceVisit(
              startTime: DateTime.parse('2026-05-${day.toString().padLeft(2, '0')}T10:00:00.000+06:00'),
              endTime: DateTime.parse('2026-05-${day.toString().padLeft(2, '0')}T18:00:00.000+06:00'),
              name: 'Work',
              semanticType: 'TYPE_WORK',
            ),
          TimelinePlaceVisit(
            startTime: DateTime.parse('2026-05-12T10:35:00.000+06:00'),
            endTime: DateTime.parse('2026-05-12T18:00:00.000+06:00'),
            name: 'Work',
            semanticType: 'TYPE_WORK',
          ),
          TimelinePlaceVisit(
            startTime: DateTime.parse('2026-05-23T10:48:00.000+06:00'),
            endTime: DateTime.parse('2026-05-23T18:00:00.000+06:00'),
            name: 'Work',
            semanticType: 'TYPE_WORK',
          ),
          TimelinePlaceVisit(
            startTime: DateTime.parse('2026-05-24T10:39:00.000+06:00'),
            endTime: DateTime.parse('2026-05-24T18:00:00.000+06:00'),
            name: 'Work',
            semanticType: 'TYPE_WORK',
          ),
        ],
      ),
      dataMonthStart: DateTime(2026, 5, 1),
      dataMonthEnd: DateTime(2026, 5, 31, 23, 59, 59, 999, 999),
      workAddress: workAddress,
      workHours: workHours,
      fuel: const MobilityFuelSummary(
        totalSpend: 2000,
        refuelCount: 4,
        currency: 'BDT',
      ),
    );

    expect(text, startsWith('Mobility Summary'));
    expect(text, contains('Travel:'));
    expect(text, contains('- Distance: 478.22 km'));
    expect(text, contains('- Travel Time: 2h 50m'));
    expect(text, contains('Work Attendance:'));
    expect(text, contains('- Workdays: 14'));
    expect(text, contains('- Late arrivals: 3'));
    expect(text, contains('- Late arrival rate: 21.4%'));
    expect(text, contains('Late Arrivals:'));
    expect(text, contains('- 12 May: 10:35'));
    expect(text, contains('- 23 May: 10:48'));
    expect(text, contains('- 24 May: 10:39'));
    expect(text, contains('Fuel:'));
    expect(text, contains('- Total fuel spend: 2,000 BDT'));
    expect(text, contains('- Refuels: 4'));
  });

  test('mobilityFuelSummaryFromExpenses aggregates fuel transactions', () {
    final fuel = mobilityFuelSummaryFromExpenses(
      ExpensesSummary(
        transactions: [
          CashewTransaction(
            account: 'Bank',
            amount: -500,
            currency: 'BDT',
            date: DateTime(2026, 5, 2),
            isIncome: false,
            category: 'Transport',
            subcategory: 'Fuel',
          ),
          CashewTransaction(
            account: 'Bank',
            amount: -1500,
            currency: 'BDT',
            date: DateTime(2026, 5, 10),
            isIncome: false,
            category: 'Fuel',
          ),
        ],
      ),
    );

    expect(fuel, isNotNull);
    expect(fuel!.totalSpend, 2000);
    expect(fuel.refuelCount, 2);
    expect(fuel.currency, 'BDT');
  });
}
