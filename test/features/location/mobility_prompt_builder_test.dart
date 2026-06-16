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
    expect(text, contains('Attendance Summary:'));
    expect(text, contains('- Workdays: 14'));
    expect(text, contains('- Late arrivals: 3'));
    expect(text, contains('- Late arrival rate: 21.4%'));
    expect(text, contains('- Average delay:'));
    expect(text, contains('- Worst delay:'));
    expect(text, contains('- Total late minutes:'));
    expect(text, contains('Late Arrival:'));
    expect(text, contains('- 12 May'));
    expect(text, contains('  Scheduled: 10:30'));
    expect(text, contains('  Actual: 10:35'));
    expect(text, contains('  Delay: 5 min'));
    expect(text, contains('Fuel:'));
    expect(text, contains('- Total fuel spend: 2,000 BDT'));
    expect(text, contains('- Refuels: 4'));
  });

  test('includes weekend motorcycle block when weekend days are configured', () {
    final text = buildMobilityPromptText(
      summary: LocationSummary(
        activities: [
          TimelineActivity(
            startTime: DateTime.parse('2026-05-08T10:00:00.000+06:00'),
            endTime: DateTime.parse('2026-05-08T10:30:00.000+06:00'),
            type: 'MOTORCYCLING',
            distanceMeters: 4000,
          ),
          TimelineActivity(
            startTime: DateTime.parse('2026-05-09T10:00:00.000+06:00'),
            endTime: DateTime.parse('2026-05-09T10:20:00.000+06:00'),
            type: 'MOTORCYCLING',
            distanceMeters: 5000,
          ),
          TimelineActivity(
            startTime: DateTime.parse('2026-05-09T18:00:00.000+06:00'),
            endTime: DateTime.parse('2026-05-09T18:20:00.000+06:00'),
            type: 'MOTORCYCLING',
            distanceMeters: 2000,
          ),
          TimelineActivity(
            startTime: DateTime.parse('2026-05-09T12:00:00.000+06:00'),
            endTime: DateTime.parse('2026-05-09T12:15:00.000+06:00'),
            type: 'WALKING',
            distanceMeters: 1000,
          ),
        ],
      ),
      dataMonthStart: DateTime(2026, 5, 1),
      dataMonthEnd: DateTime(2026, 5, 31, 23, 59, 59, 999, 999),
      weekendDays: const [DateTime.friday, DateTime.saturday],
    );

    expect(text, contains('Travel:'));
    expect(text, contains('- Weekend motorcycle (Friday and Saturday):'));
    expect(text, contains('- 8 May: 4.00 km'));
    expect(text, contains('- 9 May: 7.00 km'));
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
