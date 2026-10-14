enum CalendarEventType {
  holiday('Holiday'),
  work('Work'),
  social('Social'),
  personal('Personal'),
  travel('Travel'),
  family('Family'),
  errand('Errand'),
  other('Other');

  const CalendarEventType(this.label);

  final String label;
}

CalendarEventType classifyCalendarEvent({
  required String title,
  required bool isHoliday,
}) {
  if (isHoliday) return CalendarEventType.holiday;

  final lower = title.trim().toLowerCase();
  if (_matchesAny(lower, const [
    'errand',
    'bring',
    'pickup',
    'grocery',
    'dentist',
    'doctor',
    'mango',
    'pharmacy',
    'bank',
    'appointment',
  ])) {
    return CalendarEventType.errand;
  }
  if (_matchesAny(lower, const [
    'office',
    'training',
    'work',
    'interview',
    'meeting',
    'conference',
    'standup',
    'deadline',
  ])) {
    return CalendarEventType.work;
  }
  if (_matchesAny(lower, const [
    'trip',
    'travel',
    'vacation',
    'flight',
    'cox',
    'tour',
  ])) {
    return CalendarEventType.travel;
  }
  if (_matchesAny(lower, const [
    'family',
    'parents',
    'mom',
    'dad',
    'relative',
  ])) {
    return CalendarEventType.family;
  }
  if (_matchesAny(lower, const [
    'friend',
    'meet',
    'party',
    'wedding',
    'social',
    'dinner',
    'hangout',
    'reunion',
  ])) {
    return CalendarEventType.social;
  }
  if (_matchesAny(lower, const [
    'personal',
    'razor',
    'haircut',
    'gym',
    'self',
  ])) {
    return CalendarEventType.personal;
  }

  return CalendarEventType.other;
}

bool _matchesAny(String haystack, List<String> needles) {
  for (final needle in needles) {
    if (haystack.contains(needle)) return true;
  }
  return false;
}
