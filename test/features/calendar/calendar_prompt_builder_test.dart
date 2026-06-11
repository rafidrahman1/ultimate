import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/health/health_summary.dart';

DailySleepEntry _night(
  int day, {
  required int hours,
  required int minutes,
  required int bedH,
  required int bedM,
}) {
  final wakeDate = DateTime(2026, 5, day);
  return DailySleepEntry(
    wakeDate: wakeDate,
    session: SleepSummary(
      duration: Duration(hours: hours, minutes: minutes),
      startTime: DateTime(2026, 5, day - 1, bedH, bedM),
      endTime: DateTime(2026, 5, day, 7, 0),
    ),
  );
}

MonthlyHealthSummary _health(List<DailySleepEntry> nights) {
  return MonthlyHealthSummary(
    periodStart: DateTime(2026, 5, 1),
    periodEnd: DateTime(2026, 5, 31),
    dailySleep: nights,
    dayCount: 31,
  );
}

void main() {
  test('formats structured calendar prompt with major events and impact window', () {
    final text = buildCalendarPromptText(
      CalendarSummary(
        events: [
          CalendarEvent(
            title: 'Office Training',
            start: DateTime(2026, 5, 20),
            end: DateTime(2026, 5, 22),
            allDay: true,
          ),
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
      health: _health([
        _night(22, hours: 5, minutes: 0, bedH: 1, bedM: 30),
        _night(23, hours: 5, minutes: 0, bedH: 1, bedM: 45),
        _night(26, hours: 5, minutes: 0, bedH: 2, bedM: 10),
        _night(27, hours: 4, minutes: 0, bedH: 2, bedM: 30),
        _night(28, hours: 5, minutes: 30, bedH: 1, bedM: 50),
        _night(29, hours: 5, minutes: 0, bedH: 2, bedM: 5),
        _night(30, hours: 5, minutes: 15, bedH: 2, bedM: 20),
        _night(16, hours: 8, minutes: 0, bedH: 23, bedM: 0),
      ]),
    );

    expect(text, startsWith('Major Events'));
    expect(text, contains('20–21 May'));
    expect(text, contains('- Office Training'));
    expect(text, contains('- Overnight travel: Yes'));
    expect(text, contains('25–31 May'));
    expect(text, contains('- Eid al-Adha'));
    expect(text, contains('- Duration: 7 days'));
    expect(text, contains('Event Impact Window'));
    expect(text, contains('Office Training:'));
    expect(text, contains('- Sleep anomalies during event: 0'));
    expect(text, contains('- Sleep anomalies within 3 days after: 2'));
    expect(text, contains('Eid:'));
    expect(text, contains('- Sleep anomalies during holiday: 5'));
    expect(text, contains('- Late bedtimes during holiday: 4'));
  });

  test('returns empty calendar message when no events are synced', () {
    expect(
      buildCalendarPromptText(const CalendarSummary(events: [])),
      'No Google Calendar events synced.',
    );
  });
}
