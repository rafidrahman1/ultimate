import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/reminders/prediction_notification_service.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Reminder switches and the lead-time picker for the General settings screen.
///
/// Stateless: the screen owns the values and persistence, this only renders
/// them and reports taps.
class NotificationsCard extends StatelessWidget {
  const NotificationsCard({
    super.key,
    required this.reminderLoading,
    required this.times,
    required this.predictionRemindersEnabled,
    required this.predictionCalendarEnabled,
    required this.odometerEnabled,
    required this.onPredictionReminders,
    required this.onPredictionCalendar,
    required this.onRemoveCalendarEvents,
    required this.onOdometer,
    required this.onPickLead,
    required this.onSendTest,
  });

  final bool reminderLoading;
  final ReminderTimes times;
  final bool predictionRemindersEnabled;
  final bool predictionCalendarEnabled;
  final bool odometerEnabled;
  final ValueChanged<bool> onPredictionReminders;
  final ValueChanged<bool> onPredictionCalendar;
  final VoidCallback onRemoveCalendarEvents;
  final ValueChanged<bool> onOdometer;
  final VoidCallback onPickLead;
  final VoidCallback onSendTest;

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
          ListTile(
            contentPadding: const EdgeInsets.only(left: 32, right: 16),
            leading: const Icon(Icons.event_busy_outlined),
            title: const Text('Remove app events from calendar'),
            subtitle: const Text(
              'Deletes every event this app created in your Google Calendar.',
            ),
            enabled: !reminderLoading,
            onTap: onRemoveCalendarEvents,
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
