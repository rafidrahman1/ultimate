import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';

DailySleepEntry _night(
  int month,
  int day, {
  required int hours,
  required int minutes,
  required int bedH,
  required int bedM,
}) {
  final wakeDate = DateTime(2026, month, day);
  return DailySleepEntry(
    wakeDate: wakeDate,
    session: SleepSummary(
      duration: Duration(hours: hours, minutes: minutes),
      startTime: DateTime(2026, month, day - 1, bedH, bedM),
      endTime: DateTime(2026, month, day, 7, 0),
    ),
  );
}

MonthlyHealthSummary _health(List<DailySleepEntry> nights) {
  return MonthlyHealthSummary(
    periodStart: DateTime(2026, 7, 1),
    periodEnd: DateTime(2026, 7, 31),
    dailySleep: nights,
    dayCount: 31,
  );
}

void main() {
  test('formats calendar events with tags and no impact window in prompt', () {
    final text = buildCalendarPromptText(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Wedding invitation',
            start: DateTime(2026, 7, 12, 19, 0),
            end: DateTime(2026, 7, 12, 23, 0),
            allDay: false,
          ),
          CalendarEvent(
            title: 'Family visit',
            start: DateTime(2026, 7, 18),
            end: DateTime(2026, 7, 19),
            allDay: true,
          ),
          CalendarEvent(
            title: "Cox's Bazar Trip",
            start: DateTime(2026, 7, 24),
            end: DateTime(2026, 7, 27),
            allDay: true,
          ),
          CalendarEvent(
            title: 'Job interview',
            start: DateTime(2026, 7, 31, 10, 0),
            end: DateTime(2026, 7, 31, 11, 0),
            allDay: false,
          ),
        ],
      ),
    );

    expect(text, startsWith('Calendar Events'));
    expect(text, contains('12 Jul'));
    expect(text, contains('- Wedding invitation'));
    expect(text, contains('- Evening event'));
    expect(text, contains('18 Jul'));
    expect(text, contains('- Family visit'));
    expect(text, contains('- Overnight stay: No'));
    expect(text, contains('24–26 Jul'));
    expect(text, contains("- Cox's Bazar Trip"));
    expect(text, contains('- Overnight stay: Yes'));
    expect(text, contains('31 Jul'));
    expect(text, contains('- Job interview'));
    expect(text, contains('- Morning event'));
    expect(text, isNot(contains('Calendar Impact')));
    expect(text, isNot(contains('Event Impact Window')));
  });

  test('tags timed events by time of day', () {
    final text = buildCalendarPromptText(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Breakfast meetup',
            start: DateTime(2026, 7, 8, 8, 30),
            end: DateTime(2026, 7, 8, 9, 30),
            allDay: false,
          ),
          CalendarEvent(
            title: 'Client call',
            start: DateTime(2026, 7, 9, 14, 0),
            end: DateTime(2026, 7, 9, 15, 0),
            allDay: false,
          ),
          CalendarEvent(
            title: 'Dinner party',
            start: DateTime(2026, 7, 10, 19, 0),
            end: DateTime(2026, 7, 10, 22, 0),
            allDay: false,
          ),
          CalendarEvent(
            title: 'Late show',
            start: DateTime(2026, 7, 11, 23, 0),
            end: DateTime(2026, 7, 12, 1, 0),
            allDay: false,
          ),
        ],
      ),
    );

    expect(text, contains('- Morning event'));
    expect(text, contains('- Afternoon event'));
    expect(text, contains('- Evening event'));
    expect(text, contains('- Night event'));
  });

  test('builds calendar impact derived metrics', () {
    final impact = buildCalendarImpactDerivedText(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Wedding invitation',
            start: DateTime(2026, 7, 12, 19, 0),
            end: DateTime(2026, 7, 12, 23, 0),
            allDay: false,
          ),
          CalendarEvent(
            title: "Cox's Bazar Trip",
            start: DateTime(2026, 7, 24),
            end: DateTime(2026, 7, 27),
            allDay: true,
          ),
          CalendarEvent(
            title: 'Job interview',
            start: DateTime(2026, 7, 31, 10, 0),
            end: DateTime(2026, 7, 31, 11, 0),
            allDay: false,
          ),
        ],
      ),
      health: _health([
        _night(7, 13, hours: 5, minutes: 0, bedH: 1, bedM: 30),
        _night(7, 25, hours: 5, minutes: 0, bedH: 2, bedM: 10),
        _night(7, 26, hours: 4, minutes: 30, bedH: 2, bedM: 30),
      ]),
      expenses: ExpensesSummary(
        transactions: [
          for (final day in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
            CashewTransaction(
              account: 'Bank',
              amount: -100,
              currency: 'BDT',
              date: DateTime(2026, 7, day),
              isIncome: false,
              subcategory: 'Fuel',
            ),
          CashewTransaction(
            account: 'Bank',
            amount: -900,
            currency: 'BDT',
            date: DateTime(2026, 7, 25),
            isIncome: false,
            subcategory: 'Fuel',
          ),
        ],
      ),
    );

    expect(impact, contains('Wedding:'));
    expect(impact, contains('Sleep anomalies within 2 days after: 1'));
    expect(impact, contains('Trip:'));
    expect(impact, contains('Sleep anomalies during trip: 2'));
    expect(impact, contains('Fuel increase: +'));
    expect(impact, contains('Interview:'));
    expect(impact, contains('No measurable impact'));
  });

  test('formats holiday blocks in calendar events', () {
    final text = buildCalendarPromptText(
      CalendarSummary(
        events: [
          for (final day in [25, 26, 27, 28, 29, 30, 31])
            CalendarEvent(
              title: day == 27 ? 'Eid al-Adha' : 'Eid al-Adha Holiday',
              start: DateTime(2026, 5, day),
              end: DateTime(2026, 5, day + 1),
              allDay: true,
              isHoliday: true,
            ),
        ],
      ),
    );

    expect(text, contains('Calendar Events'));
    expect(text, contains('25–31 May'));
    expect(text, contains('- Eid al-Adha'));
    expect(text, contains('- Duration: 7 days'));
  });

  test('returns empty calendar message when no events are synced', () {
    expect(
      buildCalendarPromptText(const CalendarSummary(events: [])),
      'No Google Calendar events synced.',
    );
  });

  test('includes upcoming events after the analysis period', () {
    final periodEvents = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Office Training',
          start: DateTime(2026, 5, 20),
          end: DateTime(2026, 5, 22),
          allDay: true,
        ),
      ],
    );
    final syncedEvents = CalendarSummary(
      events: [
        ...periodEvents.events,
        CalendarEvent(
          title: 'Family Visit',
          start: DateTime(2026, 6, 5),
          end: DateTime(2026, 6, 7),
          allDay: true,
        ),
        CalendarEvent(
          title: 'Dentist',
          start: DateTime(2026, 6, 12, 10, 0),
          end: DateTime(2026, 6, 12, 11, 0),
          allDay: false,
        ),
      ],
    );

    final text = buildCalendarPromptText(
      periodEvents,
      upcomingSource: syncedEvents,
      upcomingAfter: DateTime(2026, 5, 31, 23, 59, 59),
    );

    expect(text, contains('Calendar Events'));
    expect(text, contains('Office Training'));
    expect(text, contains('Upcoming Events'));
    expect(text, contains('Family Visit'));
    expect(text, contains('Dentist'));
    expect(text, contains('5–6 Jun'));
  });
}
