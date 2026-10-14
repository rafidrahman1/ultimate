import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/prediction_notification_service.dart';
import 'package:personal/shared/widgets/app_card.dart';

const kWeekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Reminder switches and time pickers for the General settings screen.
///
/// Stateless: the screen owns the values and persistence, this only renders
/// them and reports taps.
class NotificationsCard extends StatelessWidget {
  const NotificationsCard({
    super.key,
    required this.reminderLoading,
    required this.times,
    required this.monthEndEnabled,
    required this.weekEndEnabled,
    required this.predictionRemindersEnabled,
    required this.predictionCalendarEnabled,
    required this.odometerEnabled,
    required this.onMonthEnd,
    required this.onWeekEnd,
    required this.onPredictionReminders,
    required this.onPredictionCalendar,
    required this.onOdometer,
    required this.onPickLead,
    required this.onPickTime,
    required this.onPickDigest,
    required this.onSendTest,
  });

  final bool reminderLoading;
  final ReminderTimes times;
  final bool monthEndEnabled;
  final bool weekEndEnabled;
  final bool predictionRemindersEnabled;
  final bool predictionCalendarEnabled;
  final bool odometerEnabled;
  final ValueChanged<bool> onMonthEnd;
  final ValueChanged<bool> onWeekEnd;
  final ValueChanged<bool> onPredictionReminders;
  final ValueChanged<bool> onPredictionCalendar;
  final ValueChanged<bool> onOdometer;
  final VoidCallback onPickLead;
  final Future<void> Function(int initial, Future<void> Function(int) save)
  onPickTime;
  final VoidCallback onPickDigest;
  final VoidCallback onSendTest;

  static String _formatMinutes(BuildContext context, int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  String _leadLabel() => switch (times.leadDays) {
    0 => 'On the day',
    1 => 'The day before',
    final n => '$n days before',
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Month-end analysis reminder'),
            subtitle: Text(
              reminderLoading
                  ? 'Loading reminder preference...'
                  : 'Notify at month end to analyze the next month.',
            ),
            value: monthEndEnabled,
            onChanged: reminderLoading
                ? null
                : (enabled) => onMonthEnd(enabled),
          ),
          Divider(height: 1, color: context.palette.border),
          SwitchListTile(
            title: const Text('Weekly checklist reminder'),
            subtitle: const Text('Nudge at the end of each checklist week.'),
            value: weekEndEnabled,
            onChanged: reminderLoading ? null : (enabled) => onWeekEnd(enabled),
          ),
          Divider(height: 1, color: context.palette.border),
          SwitchListTile(
            title: const Text('Prediction reminders'),
            subtitle: const Text(
              'The day before a predicted bill, refuel, '
              'service or commute, plus a Sunday summary.',
            ),
            value: predictionRemindersEnabled,
            onChanged: reminderLoading ? null : onPredictionReminders,
          ),
          if (predictionRemindersEnabled) ...[
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: const Text('Remind me'),
              subtitle: Text(_leadLabel()),
              onTap: onPickLead,
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: const Text('Reminder time'),
              subtitle: Text(_formatMinutes(context, times.predictionMinutes)),
              onTap: () => onPickTime(
                times.predictionMinutes,
                (m) => PredictionNotificationService.saveTimes(
                  predictionMinutes: m,
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: const Text('Weekly summary day'),
              subtitle: Text(
                '${kWeekdayNames[times.digestWeekday - 1]}'
                ' at ${_formatMinutes(context, times.digestMinutes)}',
              ),
              onTap: onPickDigest,
            ),
          ],
          Divider(height: 1, color: context.palette.border),
          SwitchListTile(
            title: const Text('Add predictions to calendar'),
            subtitle: const Text(
              'All-day events in your Google Calendar for '
              'dated predictions, kept up to date as they '
              'change.',
            ),
            value: predictionCalendarEnabled,
            onChanged: reminderLoading ? null : onPredictionCalendar,
          ),
          Divider(height: 1, color: context.palette.border),
          SwitchListTile(
            title: const Text('Odometer reminder'),
            subtitle: const Text(
              'On the 1st of each month, and each evening '
              'until it is logged.',
            ),
            value: odometerEnabled,
            onChanged: reminderLoading ? null : onOdometer,
          ),
          if (odometerEnabled)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              title: const Text('Odometer reminder time'),
              subtitle: Text(_formatMinutes(context, times.odometerMinutes)),
              onTap: () => onPickTime(
                times.odometerMinutes,
                (m) =>
                    PredictionNotificationService.saveTimes(odometerMinutes: m),
              ),
            ),
          Divider(height: 1, color: context.palette.border),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Send a test notification'),
            subtitle: const Text('Check that alerts reach you.'),
            onTap: onSendTest,
          ),
        ],
      ),
    );
  }
}
