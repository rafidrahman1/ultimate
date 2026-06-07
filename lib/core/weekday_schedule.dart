/// [DateTime.weekday] values (Monday = 1 … Sunday = 7).
const weekdayDisplayOrder = [7, 1, 2, 3, 4, 5, 6];

const weekdayShortLabels = <int, String>{
  DateTime.monday: 'Mon',
  DateTime.tuesday: 'Tue',
  DateTime.wednesday: 'Wed',
  DateTime.thursday: 'Thu',
  DateTime.friday: 'Fri',
  DateTime.saturday: 'Sat',
  DateTime.sunday: 'Sun',
};

const weekdayFullLabels = <int, String>{
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
};

String weekdayShortLabel(int weekday) =>
    weekdayShortLabels[weekday] ?? weekday.toString();

String weekdayFullLabel(int weekday) =>
    weekdayFullLabels[weekday] ?? weekday.toString();

List<int> parseWeekendDaysFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final days = <int>{};
  for (final value in raw) {
    if (value is! num) continue;
    final day = value.toInt();
    if (day >= DateTime.monday && day <= DateTime.sunday) {
      days.add(day);
    }
  }
  return days.toList()..sort();
}

String formatWeekdayList(Iterable<int> weekdays) {
  final names = weekdayDisplayOrder
      .where(weekdays.contains)
      .map(weekdayFullLabel)
      .toList();
  if (names.isEmpty) return '';
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]} and ${names[1]}';
  return '${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}';
}
