import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/location/timeline_activity.dart';

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
  test('formats raw calendar events with type and without redundant fields', () {
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
    expect(text, contains('- Type: Social'));
    expect(text, isNot(contains('Evening event')));
    expect(text, contains('18 Jul'));
    expect(text, contains('- Family visit'));
    expect(text, contains('- Type: Family'));
    expect(text, isNot(contains('Overnight stay: No')));
    expect(text, contains('24–26 Jul'));
    expect(text, contains("- Cox's Bazar Trip"));
    expect(text, contains('- Type: Travel'));
    expect(text, contains('- Overnight stay: Yes'));
    expect(text, contains('31 Jul'));
    expect(text, contains('- Job interview'));
    expect(text, contains('- Type: Work'));
    expect(text, isNot(contains('Morning event')));
    expect(text, isNot(contains('Calendar Impact')));
    expect(text, isNot(contains('Event Analysis')));
  });

  test('classifies events by type', () {
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
            title: 'Office standup',
            start: DateTime(2026, 7, 9, 14, 0),
            end: DateTime(2026, 7, 9, 15, 0),
            allDay: false,
          ),
          CalendarEvent(
            title: 'Bring mango Office',
            start: DateTime(2026, 7, 10, 19, 0),
            end: DateTime(2026, 7, 10, 22, 0),
            allDay: false,
          ),
        ],
      ),
    );

    expect(text, contains('- Type: Social'));
    expect(text, contains('- Type: Work'));
    expect(text, contains('- Type: Errand'));
    expect(text, isNot(contains('- Morning event')));
  });

  test('builds event analysis metrics separately from raw events', () {
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
            title: "Cox's Bazar Trip",
            start: DateTime(2026, 7, 24),
            end: DateTime(2026, 7, 27),
            allDay: true,
          ),
        ],
      ),
      health: _health([
        _night(7, 9, hours: 7, minutes: 30, bedH: 23, bedM: 0),
        _night(7, 10, hours: 7, minutes: 15, bedH: 23, bedM: 0),
        _night(7, 11, hours: 7, minutes: 0, bedH: 23, bedM: 0),
        _night(7, 12, hours: 5, minutes: 0, bedH: 1, bedM: 30),
        _night(7, 13, hours: 5, minutes: 0, bedH: 1, bedM: 30),
        _night(7, 25, hours: 5, minutes: 0, bedH: 2, bedM: 10),
        _night(7, 26, hours: 4, minutes: 30, bedH: 2, bedM: 30),
      ]),
      expenses: ExpensesSummary(
        transactions: [
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
      location: LocationSummary(
        activities: [
          TimelineActivity(
            startTime: DateTime(2026, 7, 25, 9, 0),
            endTime: DateTime(2026, 7, 25, 11, 12),
            type: 'MOTORCYCLING',
            distanceMeters: 44940,
          ),
        ],
      ),
      includeEventAnalysis: true,
    );

    expect(text, contains('Calendar Events'));
    expect(text, contains('Event Analysis'));
    expect(text, contains('Wedding'));
    expect(text, contains('Sleep:'));
    expect(text, contains('- During:'));
    expect(text, contains('- Difference:'));
    expect(text, contains('- Confidence:'));
    expect(text, contains('Spending:'));
    expect(text, contains('Mobility:'));
    expect(text, contains('Impact:'));
    expect(text, isNot(contains('Calendar Impact')));
  });

  test('omits event analysis for low-signal single-day events', () {
    final text = buildCalendarPromptText(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Office standup',
            start: DateTime(2026, 7, 9, 14, 0),
            end: DateTime(2026, 7, 9, 15, 0),
            allDay: false,
          ),
        ],
      ),
      health: _health([
        _night(7, 8, hours: 7, minutes: 10, bedH: 23, bedM: 0),
        _night(7, 9, hours: 7, minutes: 0, bedH: 23, bedM: 0),
        _night(7, 10, hours: 6, minutes: 55, bedH: 23, bedM: 0),
      ]),
      expenses: ExpensesSummary(
        transactions: [
          CashewTransaction(
            account: 'Bank',
            amount: -120,
            currency: 'BDT',
            date: DateTime(2026, 7, 9),
            isIncome: false,
            subcategory: 'Snacks',
          ),
        ],
      ),
      includeEventAnalysis: true,
    );

    expect(text, contains('Office standup'));
    expect(text, isNot(contains('Event Analysis')));
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
    expect(text, contains('- Type: Holiday'));
    expect(text, contains('- Duration: 7 days'));
  });

  test('omits single-day holiday duration', () {
    final text = buildCalendarPromptText(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Buddha Purnima/Vesak',
            start: DateTime(2026, 5, 1),
            end: DateTime(2026, 5, 2),
            allDay: true,
            isHoliday: true,
          ),
        ],
      ),
    );

    expect(text, contains('1 May'));
    expect(text, contains('- Buddha Purnima/Vesak'));
    expect(text, isNot(contains('Duration: 1 day')));
  });

  test('returns empty calendar message when no events are synced', () {
    expect(
      buildCalendarPromptText(const CalendarSummary(events: [])),
      'No Google Calendar events synced.',
    );
  });

  test('puts future events in a separate section when enabled', () {
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

    final retrospective = buildCalendarPromptText(
      periodEvents,
      upcomingSource: syncedEvents,
      upcomingAfter: DateTime(2026, 5, 31, 23, 59, 59),
    );
    expect(retrospective, contains('Calendar Events'));
    expect(retrospective, contains('Office Training'));
    expect(retrospective, isNot(contains('Future Events')));
    expect(retrospective, isNot(contains('Family Visit')));

    final planning = buildCalendarPromptText(
      periodEvents,
      upcomingSource: syncedEvents,
      upcomingAfter: DateTime(2026, 5, 31, 23, 59, 59),
      includeFutureEvents: true,
    );

    expect(planning, contains('Future Events'));
    expect(planning, contains('Family Visit'));
    expect(planning, contains('Dentist'));
    expect(planning, contains('5–6 Jun'));
  });

  test('includes motorcycle movement and purchases during calendar events', () {
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
            title: "Cox's Bazar Trip",
            start: DateTime(2026, 7, 24),
            end: DateTime(2026, 7, 27),
            allDay: true,
          ),
        ],
      ),
      location: LocationSummary(
        activities: [
          TimelineActivity(
            startTime: DateTime(2026, 7, 12, 20, 0),
            endTime: DateTime(2026, 7, 12, 20, 45),
            type: 'MOTORCYCLING',
            distanceMeters: 12500,
          ),
          TimelineActivity(
            startTime: DateTime(2026, 7, 25, 9, 0),
            endTime: DateTime(2026, 7, 25, 10, 30),
            type: 'MOTORCYCLING',
            distanceMeters: 42000,
          ),
          TimelineActivity(
            startTime: DateTime(2026, 7, 10, 8, 0),
            endTime: DateTime(2026, 7, 10, 8, 30),
            type: 'MOTORCYCLING',
            distanceMeters: 5000,
          ),
        ],
      ),
      expenses: ExpensesSummary(
        transactions: [
          CashewTransaction(
            account: 'Bank',
            amount: -3500,
            currency: 'BDT',
            date: DateTime(2026, 7, 12, 20, 0),
            isIncome: false,
            subcategory: 'Gift',
            title: 'Wedding gift',
          ),
          CashewTransaction(
            account: 'Bank',
            amount: -1200,
            currency: 'BDT',
            date: DateTime(2026, 7, 25),
            isIncome: false,
            subcategory: 'Restaurant',
          ),
          CashewTransaction(
            account: 'Bank',
            amount: -500,
            currency: 'BDT',
            date: DateTime(2026, 7, 1),
            isIncome: false,
            subcategory: 'Snacks',
          ),
        ],
      ),
    );

    expect(text, contains('- Wedding invitation'));
    expect(text, contains('- Motorcycle movement: 12.50 km'));
    expect(text, contains('- Purchase: Gift · Wedding gift · 3,500 BDT'));
    expect(text, isNot(contains('- Purchase: Snacks')));
    expect(text, contains("- Cox's Bazar Trip"));
    expect(text, contains('- Motorcycle movement: 42.00 km'));
    expect(text, contains('- Purchase: Restaurant · 1,200 BDT'));
  });

  test('builds sleep cluster correlation against calendar events', () {
    final nights = <DailySleepEntry>[
      for (var day = 23; day <= 31; day++)
        _night(
          5,
          day,
          hours: day <= 28 ? 5 : 7,
          minutes: 30,
          bedH: 23,
          bedM: 30,
        ),
    ];

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
      health: MonthlyHealthSummary(
        periodStart: DateTime(2026, 5, 1),
        periodEnd: DateTime(2026, 5, 31),
        dailySleep: nights,
        dayCount: 31,
      ),
      includeSleepClusterCorrelation: true,
    );

    expect(text, contains('Sleep Cluster Correlation'));
    expect(text, contains('Overlap:'));
    expect(text, contains('Eid al-Adha'));
    expect(text, contains('Cluster nights overlapping event:'));
  });
}
