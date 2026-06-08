import 'package:personal/core/period_range.dart';
import 'package:personal/features/calendar/calendar_event.dart';

/// Consecutive Bangladesh public holidays merged for display and analysis.
class CalendarHolidayGroup {
  const CalendarHolidayGroup({
    required this.title,
    required this.start,
    required this.end,
    required this.dayCount,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final int dayCount;

  bool get isSingleDay {
    final startDay = _calendarDay(start);
    final endDay = _calendarDay(end);
    return startDay == endDay;
  }
}

/// Personal event or a grouped holiday block, sorted by start.
sealed class CalendarTimelineEntry {
  const CalendarTimelineEntry();
}

class CalendarPersonalEntry extends CalendarTimelineEntry {
  const CalendarPersonalEntry(this.event);

  final CalendarEvent event;
}

class CalendarHolidayGroupEntry extends CalendarTimelineEntry {
  const CalendarHolidayGroupEntry(this.group);

  final CalendarHolidayGroup group;
}

/// Groups consecutive all-day holidays with the same normalized name.
List<CalendarHolidayGroup> groupConsecutiveHolidays(
  Iterable<CalendarEvent> events,
) {
  final holidays = events.where((e) => e.isHoliday).toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  final groups = <CalendarHolidayGroup>[];
  String? currentKey;
  DateTime? groupStart;
  DateTime? lastDay;
  final titlesInGroup = <String>[];

  void flush() {
    if (currentKey == null || groupStart == null || lastDay == null) return;
    groups.add(
      CalendarHolidayGroup(
        title: _holidayDisplayTitle(titlesInGroup),
        start: groupStart!,
        end: lastDay!,
        dayCount: titlesInGroup.length,
      ),
    );
    currentKey = null;
    groupStart = null;
    lastDay = null;
    titlesInGroup.clear();
  }

  for (final event in holidays) {
    final key = holidayGroupKey(event.title);
    final day = _calendarDay(event.start);

    if (currentKey == key &&
        lastDay != null &&
        day.difference(lastDay!).inDays == 1) {
      lastDay = day;
      titlesInGroup.add(event.title);
      continue;
    }

    flush();
    currentKey = key;
    groupStart = day;
    lastDay = day;
    titlesInGroup.add(event.title);
  }

  flush();
  return groups;
}

List<CalendarTimelineEntry> buildCalendarTimeline(List<CalendarEvent> events) {
  final personal =
      events.where((e) => !e.isHoliday).toList()..sort((a, b) => a.start.compareTo(b.start));
  final groups = groupConsecutiveHolidays(events);

  final timeline = <CalendarTimelineEntry>[
    ...personal.map(CalendarPersonalEntry.new),
    ...groups.map(CalendarHolidayGroupEntry.new),
  ];
  timeline.sort((a, b) => _entryStart(a).compareTo(_entryStart(b)));
  return timeline;
}

DateTime _entryStart(CalendarTimelineEntry entry) => switch (entry) {
      CalendarPersonalEntry(:final event) => event.start,
      CalendarHolidayGroupEntry(:final group) => group.start,
    };

String holidayGroupKey(String title) {
  return title
      .replaceAll(RegExp(r'\s*\(tentative\)\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+Holiday\s*$', caseSensitive: false), '')
      .trim()
      .toLowerCase();
}

String _holidayDisplayTitle(List<String> titles) {
  if (titles.isEmpty) return '';
  final withoutTentative = titles
      .map(
        (t) => t.replaceAll(
          RegExp(r'\s*\(tentative\)\s*', caseSensitive: false),
          '',
        ),
      )
      .toList();
  final shortest = withoutTentative.reduce(
    (a, b) => a.length <= b.length ? a : b,
  );
  final anyTentative = titles.any(
    (t) => t.toLowerCase().contains('tentative'),
  );
  return anyTentative ? '$shortest (tentative)' : shortest;
}

DateTime _calendarDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String formatHolidayGroupForPrompt(CalendarHolidayGroup group) {
  const tag = ' [BD public holiday]';
  final dateLabel = group.isSingleDay
      ? _isoDateKey(group.start)
      : '${_isoDateKey(group.start)} – ${_isoDateKey(group.end)}';
  final daysSuffix = group.dayCount > 1 ? ', ${group.dayCount} days' : '';
  return '  - $dateLabel · ${group.title} (all day$daysSuffix)$tag';
}

String _isoDateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String formatHolidayGroupDateRange(CalendarHolidayGroup group) {
  return formatPeriodRange(group.start, group.end);
}
