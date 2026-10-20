import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';

/// One notification to fire on [day] (at the reminder hour).
typedef PlannedReminder = ({DateTime day, String title, String body});

const _papersLeadDays = [30, 7, 0];
const _serviceLeadDays = [7, 0];

/// Every reminder the data calls for, as of [today]: a few lead-time nudges
/// before each expiry or due date, and one the next day for anything already
/// past due. Past days are left out.
List<PlannedReminder> planReminders(MotoData data, DateTime today) {
  final day = dayOf(today);
  final out = <PlannedReminder>[];

  void add(
    DateTime due,
    List<int> leads,
    String title,
    String Function(int) body,
  ) {
    if (dayOf(due).isBefore(day)) {
      out.add((
        day: day.add(const Duration(days: 1)),
        title: title,
        body: body(-1),
      ));
      return;
    }
    for (final lead in leads) {
      final at = dayOf(due).subtract(Duration(days: lead));
      if (!at.isBefore(day)) out.add((day: at, title: title, body: body(lead)));
    }
  }

  for (final bike in data.bikes) {
    for (final p in data.papers.where((p) => p.bikeId == bike.id)) {
      add(
        p.expiry,
        _papersLeadDays,
        '${bike.name}: ${p.type.label}',
        (lead) => lead < 0
            ? 'Expired. Renew it.'
            : lead == 0
            ? 'Expires today.'
            : 'Expires in $lead days. Time to renew.',
      );
    }
    final rate = dailyRate(data, bike, day);
    for (final s in taskStatuses(data, bike, day)) {
      final due = expectedDueDate(s, rate, day);
      if (due == null) continue;
      add(
        due,
        _serviceLeadDays,
        '${bike.name}: ${s.task.name}',
        (lead) => lead < 0
            ? 'Overdue.'
            : lead == 0
            ? 'Due about now.'
            : 'Due in about $lead days.',
      );
    }
  }
  return out;
}
