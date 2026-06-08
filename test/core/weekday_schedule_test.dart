import 'package:flutter_test/flutter_test.dart';
import 'package:personal/core/weekday_schedule.dart';

void main() {
  test('formatWeekdayList joins selected weekend days', () {
    expect(
      formatWeekdayList(const [DateTime.friday, DateTime.saturday]),
      'Friday and Saturday',
    );
    expect(
      formatWeekdayList(const [DateTime.sunday, DateTime.friday]),
      'Sunday and Friday',
    );
  });

  test('parseWeekendDaysFromJson ignores invalid values', () {
    expect(parseWeekendDaysFromJson([5, 6, 99, 'bad']), [5, 6]);
  });
}
