import 'package:flutter_test/flutter_test.dart';
import 'package:motohealth/features/garage/backup.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';

Bike bike({double odo = 1000, DateTime? added}) => Bike(
  id: 'b',
  name: 'Test',
  addedOn: added ?? DateTime(2026, 1, 1),
  startOdometer: odo,
  tasks: const [
    ServiceTask(id: 'oil', name: 'Oil', intervalKm: 3000, intervalDays: 180),
    ServiceTask(id: 'chain', name: 'Chain', intervalKm: 500),
  ],
);

FuelEntry fill(
  String id,
  DateTime date,
  double odo,
  double litres, {
  bool full = true,
  double cost = 0,
}) => FuelEntry(
  id: id,
  bikeId: 'b',
  date: date,
  odometer: odo,
  litres: litres,
  cost: cost,
  fullTank: full,
);

void main() {
  group('fuelStats', () {
    test('a fill without odometer adds litres but never ends a stretch', () {
      final stats = fuelStats([
        fill('1', DateTime(2026, 1, 1), 1000, 10),
        FuelEntry(
          id: '2',
          bikeId: 'b',
          date: DateTime(2026, 1, 10),
          litres: 4,
          cost: 0,
        ),
        fill('3', DateTime(2026, 1, 20), 1300, 6),
      ]);
      expect(stats.segments, hasLength(1));
      expect(stats.segments.single.km, 300);
      expect(stats.segments.single.litres, 10);
      expect(stats.totalLitres, 20);
    });

    test('measures mileage between full tanks', () {
      final stats = fuelStats([
        fill('1', DateTime(2026, 1, 1), 1000, 10, cost: 1000),
        fill('2', DateTime(2026, 1, 10), 1300, 6, cost: 600),
        fill('3', DateTime(2026, 1, 20), 1600, 6, cost: 660),
      ]);
      expect(stats.segments, hasLength(2));
      expect(stats.segments.first.kmPerLitre, closeTo(50, 0.001));
      expect(stats.averageKmPerLitre, closeTo(600 / 12, 0.001));
      expect(stats.costPerKm, closeTo(1260 / 600, 0.001));
    });

    test('partial fills count toward the next full one', () {
      final stats = fuelStats([
        fill('1', DateTime(2026, 1, 1), 1000, 10),
        fill('2', DateTime(2026, 1, 5), 1100, 2, full: false),
        fill('3', DateTime(2026, 1, 10), 1200, 3),
      ]);
      expect(stats.segments, hasLength(1));
      expect(stats.segments.single.litres, 5);
      expect(stats.segments.single.km, 200);
    });

    test('needs two full tanks', () {
      final stats = fuelStats([fill('1', DateTime(2026, 1, 1), 1000, 10)]);
      expect(stats.averageKmPerLitre, isNull);
      expect(stats.segments, isEmpty);
    });
  });

  group('odometer', () {
    test('latest ignores a lower typo and estimate follows the pace', () {
      final b = bike();
      final data = MotoData(
        bikes: [b],
        readings: [
          OdometerReading(
            id: 'r1',
            bikeId: 'b',
            date: DateTime(2026, 1, 31),
            km: 1300,
          ),
          OdometerReading(
            id: 'r2',
            bikeId: 'b',
            date: DateTime(2026, 2, 2),
            km: 90,
          ),
        ],
      );
      expect(latestOdometer(data, b), 1300);
    });

    test('daily rate and estimate', () {
      final b = bike();
      final data = MotoData(
        bikes: [b],
        readings: [
          OdometerReading(
            id: 'r1',
            bikeId: 'b',
            date: DateTime(2026, 1, 11),
            km: 1100,
          ),
        ],
      );
      final today = DateTime(2026, 1, 21);
      expect(dailyRate(data, b, today), closeTo(10, 0.001));
      expect(estimatedOdometer(data, b, today), closeTo(1200, 0.001));
    });

    test('rejects a reading that runs the odometer backwards', () {
      final b = bike();
      final data = MotoData(bikes: [b]);
      expect(odometerProblem(data, b, DateTime(2026, 2, 1), 900), isNotNull);
      expect(odometerProblem(data, b, DateTime(2026, 2, 1), 1100), isNull);
    });
  });

  group('maintenance', () {
    test('a service resets the countdown for the jobs it did', () {
      final b = bike();
      final today = DateTime(2026, 2, 1);
      final data = MotoData(
        bikes: [b],
        services: [
          ServiceEntry(
            id: 's',
            bikeId: 'b',
            date: DateTime(2026, 1, 20),
            odometer: 1400,
            title: 'Oil',
            cost: 0,
            taskIds: const ['oil'],
          ),
        ],
        readings: [
          OdometerReading(
            id: 'r',
            bikeId: 'b',
            date: DateTime(2026, 2, 1),
            km: 1600,
          ),
        ],
      );
      final s = taskStatuses(data, b, today);
      final oil = s.firstWhere((t) => t.task.id == 'oil');
      expect(oil.level, DueLevel.ok);
      expect(oil.kmLeft, closeTo(3000 - 200, 0.001));
      expect(oil.neverDone, isFalse);
      // The chain was never serviced: 600 km since the bike was added.
      final chain = s.firstWhere((t) => t.task.id == 'chain');
      expect(chain.level, DueLevel.overdue);
      expect(chain.neverDone, isTrue);
    });

    test('flags a job as soon when close to its limit', () {
      final b = bike();
      final data = MotoData(
        bikes: [b],
        readings: [
          OdometerReading(
            id: 'r',
            bikeId: 'b',
            date: DateTime(2026, 1, 2),
            km: 1480,
          ),
        ],
      );
      final chain = taskStatuses(
        data,
        b,
        DateTime(2026, 1, 2),
      ).firstWhere((t) => t.task.id == 'chain');
      expect(chain.kmLeft, closeTo(20, 0.001));
      expect(chain.level, DueLevel.soon);
    });

    test('date interval alone can make a job overdue', () {
      final b = bike();
      final data = MotoData(bikes: [b]);
      final oil = taskStatuses(
        data,
        b,
        DateTime(2026, 8, 1),
      ).firstWhere((t) => t.task.id == 'oil');
      expect(oil.level, DueLevel.overdue);
      expect(oil.daysLeft, lessThan(0));
    });
  });

  group('papers and health', () {
    final today = DateTime(2026, 6, 1);
    Paper paper(int days) => Paper(
      id: '$days',
      bikeId: 'b',
      type: PaperType.insurance,
      expiry: today.add(Duration(days: days)),
    );

    test('levels', () {
      expect(paperLevel(paper(90), today), PaperLevel.valid);
      expect(paperLevel(paper(10), today), PaperLevel.soon);
      expect(paperLevel(paper(-1), today), PaperLevel.expired);
    });

    test('health score is 100 when all is well and drops with problems', () {
      final b = bike();
      final ok = taskStatuses(MotoData(bikes: [b]), b, DateTime(2026, 1, 2));
      expect(healthScore(ok, [paper(90)], today), 100);
      expect(healthScore(ok, [paper(-5)], today), 70);
      final late = taskStatuses(MotoData(bikes: [b]), b, DateTime(2026, 12, 1));
      expect(healthScore(late, const [], today), lessThan(100));
    });
  });

  test('costByCategory sums fuel, service and expenses in range', () {
    final b = bike();
    final data = MotoData(
      bikes: [b],
      fuel: [fill('f', DateTime(2026, 3, 5), 1100, 5, cost: 500)],
      services: [
        ServiceEntry(
          id: 's',
          bikeId: 'b',
          date: DateTime(2026, 3, 6),
          odometer: 1110,
          title: 'x',
          cost: 800,
        ),
      ],
      expenses: [
        Expense(
          id: 'e',
          bikeId: 'b',
          date: DateTime(2026, 2, 6),
          category: ExpenseCategory.insurance,
          amount: 3000,
        ),
      ],
    );
    final march = costByCategory(
      data,
      b,
      from: DateTime(2026, 3),
      to: DateTime(2026, 4),
    );
    expect(march, {'Fuel': 500, 'Service': 800});
    expect(totalCost(costByCategory(data, b)), 4300);
  });

  test('MotoData survives a JSON round trip', () {
    final b = bike();
    final data = MotoData(
      bikes: [b],
      fuel: [fill('f', DateTime(2026, 3, 5), 1100, 5, cost: 500)],
      papers: [
        Paper(
          id: 'p',
          bikeId: 'b',
          type: PaperType.pollution,
          expiry: DateTime(2027),
        ),
      ],
      selectedBikeId: 'b',
      currency: '৳',
      currencyCode: 'BDT',
    );
    final back = MotoData.fromJson(data.toJson());
    expect(back.bikes.single.tasks, hasLength(2));
    expect(back.fuel.single.litres, 5);
    expect(back.papers.single.type, PaperType.pollution);
    expect(back.currency, '৳');
    expect(back.currencyCode, 'BDT');
    // A save from before the picker keeps its symbol and has no code.
    final old = MotoData.fromJson({'currency': '₹'});
    expect(old.currency, '₹');
    expect(old.currencyCode, isNull);
    expect(back.selectedBike?.id, 'b');
  });

  group('odometer ordering', () {
    FuelEntry noOdo(String id, DateTime d) =>
        FuelEntry(id: id, bikeId: 'b', date: d, litres: 5, cost: 0);

    test('refuses a value below an earlier one or above a later one', () {
      final b = bike(odo: 1000);
      final data = MotoData(
        bikes: [b],
        fuel: [fill('f', DateTime(2026, 3, 1), 1500, 5)],
      );
      expect(odometerProblem(data, b, DateTime(2026, 4, 1), 1400), isNotNull);
      expect(odometerProblem(data, b, DateTime(2026, 2, 1), 1600), isNotNull);
      expect(odometerProblem(data, b, DateTime(2026, 4, 1), 1500), isNull);
      expect(odometerProblem(data, b, DateTime(2026, 2, 1), 1200), isNull);
    });

    test('an entry can be edited without clashing with itself', () {
      final b = bike(odo: 1000);
      final data = MotoData(
        bikes: [b],
        fuel: [fill('f', DateTime(2026, 3, 1), 1500, 5)],
      );
      expect(
        odometerProblem(data, b, DateTime(2026, 3, 1), 1450, exceptId: 'f'),
        isNull,
      );
    });

    test('entries without an odometer are ignored', () {
      final b = bike(odo: 1000);
      final data = MotoData(
        bikes: [b],
        fuel: [noOdo('n', DateTime(2026, 3, 1))],
      );
      expect(odometerPoints(data, b), hasLength(1));
      expect(latestOdometer(data, b), 1000);
      expect(odometerProblem(data, b, DateTime(2026, 4, 1), 1100), isNull);
    });

    test('a service without an odometer counts from the km known that day', () {
      final b = bike(odo: 1000);
      final data = MotoData(
        bikes: [b],
        readings: [
          OdometerReading(
            id: 'r',
            bikeId: 'b',
            date: DateTime(2026, 2, 1),
            km: 2000,
          ),
          OdometerReading(
            id: 'r2',
            bikeId: 'b',
            date: DateTime(2026, 5, 1),
            km: 4000,
          ),
        ],
        services: [
          ServiceEntry(
            id: 's',
            bikeId: 'b',
            date: DateTime(2026, 3, 1),
            title: 'Chain',
            cost: 0,
            taskIds: const ['chain'],
          ),
        ],
      );
      final chain = taskStatuses(
        data,
        b,
        DateTime(2026, 5, 1),
      ).firstWhere((t) => t.task.id == 'chain');
      // Counted from 2000 km (the last reading before 1 March), not 4000.
      expect(chain.dueKm, 2500);
      expect(chain.neverDone, isFalse);
    });
  });

  group('backupDue', () {
    final today = DateTime(2026, 6, 1);
    MotoData withEntries(int n, {DateTime? backup}) => MotoData(
      fuel: [
        for (var i = 0; i < n; i++) fill('$i', DateTime(2026, 1, 1), 100, 5),
      ],
      lastBackup: backup,
    );

    test('waits until there is something worth losing', () {
      expect(backupDue(withEntries(4), today), isFalse);
      expect(backupDue(withEntries(5), today), isTrue);
    });

    test('asks again after a month', () {
      expect(
        backupDue(withEntries(9, backup: DateTime(2026, 5, 20)), today),
        isFalse,
      );
      expect(
        backupDue(withEntries(9, backup: DateTime(2026, 4, 1)), today),
        isTrue,
      );
    });
  });

  group('backup', () {
    test('restores what was exported and rejects anything else', () {
      final data = MotoData(
        fuel: [fill('f', DateTime(2026, 1, 1), 1000, 5)],
        currency: '৳',
        currencyCode: 'BDT',
      );
      final back = parseBackup(backupJson(data))!;
      expect(back.fuel.single.litres, 5);
      expect(back.currencyCode, 'BDT');
      expect(parseBackup('not json'), isNull);
      expect(parseBackup('{"hello": 1}'), isNull);
    });
  });
}
