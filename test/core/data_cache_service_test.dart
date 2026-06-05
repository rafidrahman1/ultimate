import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/core/data_cache_service.dart';
import 'package:Personal/features/calendar/calendar_event.dart';
import 'package:Personal/features/expenses/cashew_transaction.dart';
import 'package:Personal/features/game_activity/game_activity_session.dart';
import 'package:Personal/features/health/health_service.dart';
import 'package:Personal/features/location/timeline_activity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('round-trips expenses summary', () async {
    final summary = ExpensesSummary(
      fileName: 'cashew.csv',
      transactions: [
        CashewTransaction(
          account: 'Cash',
          amount: -12.5,
          currency: 'BDT',
          date: DateTime(2026, 5, 20),
          isIncome: false,
          category: 'Food',
        ),
      ],
    );

    await DataCacheService.instance.saveExpenses(summary);
    final loaded = await DataCacheService.instance.loadExpenses();

    expect(loaded?.fileName, 'cashew.csv');
    expect(loaded?.transactions.length, 1);
    expect(loaded?.transactions.first.amount, -12.5);
  });

  test('round-trips location summary', () async {
    final summary = LocationSummary(
      fileName: 'Timeline.json',
      activities: [
        TimelineActivity(
          startTime: DateTime(2026, 5, 1, 10),
          endTime: DateTime(2026, 5, 1, 11),
          type: 'MOTORCYCLING',
          distanceMeters: 1500,
        ),
      ],
    );

    await DataCacheService.instance.saveLocation(summary);
    final loaded = await DataCacheService.instance.loadLocation();

    expect(loaded?.activities.length, 1);
    expect(loaded?.activities.first.isMotorcycling, isTrue);
  });

  test('round-trips game activity summary', () async {
    final summary = GameActivitySummary(
      fileName: 'export.csv',
      sessions: [
        GameActivitySession(
          name: 'Elden Ring',
          sessionDate: DateTime(2026, 5, 29),
          timePlayed: const Duration(hours: 2),
        ),
      ],
    );

    await DataCacheService.instance.saveGameActivity(summary);
    final loaded = await DataCacheService.instance.loadGameActivity();

    expect(loaded?.sessions.single.name, 'Elden Ring');
    expect(loaded?.sessions.single.timePlayed.inHours, 2);
  });

  test('round-trips calendar summary', () async {
    final summary = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Meet',
          start: DateTime(2026, 5, 30, 9),
          end: DateTime(2026, 5, 30, 10),
          allDay: false,
        ),
      ],
      accountEmail: 'user@example.com',
      syncedAt: DateTime(2026, 5, 30),
    );

    await DataCacheService.instance.saveCalendar(summary);
    final loaded = await DataCacheService.instance.loadCalendar();

    expect(loaded?.events.single.title, 'Meet');
    expect(loaded?.accountEmail, 'user@example.com');
  });

  test('round-trips monthly health without sleep points', () async {
    final periodStart = DateTime(2026, 4, 1);
    final periodEnd = DateTime(2026, 4, 30, 23, 59, 59, 999, 999);
    final day = DateTime(2026, 4, 15);
    final result = MonthlyHealthFetchResult(
      points: const [],
      periodStart: periodStart,
      periodEnd: periodEnd,
      dailySteps: {day: 4200},
      dayCount: 30,
    );

    await DataCacheService.instance.saveMonthlyHealth(result);
    final loaded = await DataCacheService.instance.loadMonthlyHealth();

    expect(loaded?.dayCount, 30);
    expect(loaded?.dailySteps[day], 4200);
  });
}
