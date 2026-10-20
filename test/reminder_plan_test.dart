import 'package:flutter_test/flutter_test.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/reminders/reminder_plan.dart';

void main() {
  final today = DateTime(2026, 6, 1);
  Bike bike() => Bike(
    id: 'b',
    name: 'Daily',
    addedOn: DateTime(2026, 6, 1),
    startOdometer: 0,
    tasks: const [],
  );
  Paper paper(DateTime expiry) =>
      Paper(id: 'p', bikeId: 'b', type: PaperType.roadTax, expiry: expiry);

  test('a paper gets 30, 7 and 0 day reminders', () {
    final plan = planReminders(
      MotoData(bikes: [bike()], papers: [paper(DateTime(2026, 8, 1))]),
      today,
    );
    expect(plan.map((r) => r.day), [
      DateTime(2026, 7, 2),
      DateTime(2026, 7, 25),
      DateTime(2026, 8, 1),
    ]);
    expect(plan.first.title, 'Daily: Tax token');
  });

  test('reminders already in the past are left out', () {
    final plan = planReminders(
      MotoData(bikes: [bike()], papers: [paper(DateTime(2026, 6, 10))]),
      today,
    );
    expect(plan.map((r) => r.day), [
      DateTime(2026, 6, 3),
      DateTime(2026, 6, 10),
    ]);
  });

  test('an expired paper gets one reminder tomorrow', () {
    final plan = planReminders(
      MotoData(bikes: [bike()], papers: [paper(DateTime(2026, 5, 1))]),
      today,
    );
    expect(plan, hasLength(1));
    expect(plan.single.day, DateTime(2026, 6, 2));
    expect(plan.single.body, 'Expired. Renew it.');
  });

  test('another bike\'s papers are not mixed in', () {
    final plan = planReminders(
      MotoData(
        bikes: [bike()],
        papers: [
          Paper(
            id: 'x',
            bikeId: 'other',
            type: PaperType.roadTax,
            expiry: DateTime(2026, 8, 1),
          ),
        ],
      ),
      today,
    );
    expect(plan, isEmpty);
  });
}
