import 'package:flutter/material.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/features/forecasts/reminders/prediction_calendar_service.dart';
import 'package:personal/features/settings/widgets/commute_alert_rows.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Notification settings for the General settings screen: delivery checks,
/// reminders sent by the phone, predictions added to Google Calendar, and
/// troubleshooting.
///
/// Stateless: the screen owns the values and persistence, this only renders
/// them and reports taps.
class NotificationsCard extends StatelessWidget {
  const NotificationsCard({
    super.key,
    required this.reminderLoading,
    required this.predictionCalendarEnabled,
    required this.calendarExcluded,
    required this.onCalendarCategory,
    required this.checkInEnabled,
    required this.onCheckIn,
    required this.onPredictionCalendar,
    required this.onRemoveCalendarEvents,
    required this.onSendTest,
    required this.health,
    required this.onFixNotifications,
    required this.onFixExactAlarms,
    required this.onFixBattery,
  });

  final bool reminderLoading;
  final bool predictionCalendarEnabled;

  /// Prediction keys switched off for the calendar.
  final Set<String> calendarExcluded;
  final void Function(String key, bool enabled) onCalendarCategory;
  final bool checkInEnabled;
  final ValueChanged<bool> onCheckIn;
  final ValueChanged<bool> onPredictionCalendar;
  final VoidCallback onRemoveCalendarEvents;
  final VoidCallback onSendTest;

  /// Null while it is being checked.
  final ReminderHealth? health;
  final VoidCallback onFixNotifications;
  final VoidCallback onFixExactAlarms;
  final VoidCallback onFixBattery;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final divider = Divider(height: 1, indent: 68, color: palette.border);
    final categories = PredictionCalendarService.categories;
    final included = categories
        .where((c) => !calendarExcluded.contains(c.key))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupLabel('Delivery'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _CheckRow(
                ok: health?.notificationsAllowed,
                title: 'Notifications allowed',
                problem: 'Blocked in system settings, so nothing can show.',
                onFix: onFixNotifications,
              ),
              divider,
              _CheckRow(
                ok: health?.exactAlarms,
                title: 'On-time alarms',
                problem: 'Not allowed, so Android may deliver reminders late.',
                onFix: onFixExactAlarms,
              ),
              divider,
              _CheckRow(
                ok: health?.batteryUnrestricted,
                title: 'Battery unrestricted',
                problem:
                    'Battery optimisation can delay or drop reminders when '
                    'the app is closed.',
                onFix: onFixBattery,
              ),
            ],
          ),
        ),
        const _GroupLabel('Reminders on this phone'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              const CommuteAlertRows(),
              divider,
              _SwitchRow(
                icon: Icons.mood_outlined,
                color: palette.health,
                title: 'Daily check-in',
                subtitle:
                    'At 21:00 to log mood, energy and stress. Skipped once '
                    'the day is logged.',
                value: checkInEnabled,
                onChanged: reminderLoading ? null : onCheckIn,
              ),
            ],
          ),
        ),
        const _GroupLabel('Google Calendar'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SwitchRow(
                icon: Icons.event_outlined,
                color: palette.calendar,
                title: 'Add predictions to calendar',
                subtitle:
                    'All-day events for dated predictions, kept up to date. '
                    'Your calendar sends the reminders.',
                value: predictionCalendarEnabled,
                onChanged: reminderLoading ? null : onPredictionCalendar,
              ),
              if (predictionCalendarEnabled) ...[
                divider,
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    68,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Include · $included of ${categories.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          for (final category in categories)
                            FilterChip(
                              label: Text(category.label),
                              selected: !calendarExcluded.contains(
                                category.key,
                              ),
                              onSelected: reminderLoading
                                  ? null
                                  : (on) =>
                                        onCalendarCategory(category.key, on),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              divider,
              _ActionRow(
                icon: Icons.event_busy_outlined,
                color: palette.statusCritical,
                title: 'Remove app events',
                subtitle:
                    'Deletes every event this app added to your calendar.',
                onTap: reminderLoading ? null : onRemoveCalendarEvents,
              ),
            ],
          ),
        ),
        const _GroupLabel('Troubleshooting'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ActionRow(
                icon: Icons.notifications_active_outlined,
                color: palette.statusNeutral,
                title: 'Send a test notification',
                subtitle: 'Check that alerts reach you.',
                onTap: onSendTest,
              ),
              divider,
              _ActionRow(
                icon: Icons.history_outlined,
                color: palette.statusNeutral,
                title: 'Sent notifications',
                subtitle: 'Everything sent in the last 30 days.',
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.notifications),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Text(
        text.toUpperCase(),
        style: context.sectionLabel.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Tinted round icon used to lead each row.
class SettingsRowIcon extends StatelessWidget {
  const SettingsRowIcon(this.icon, this.color, {super.key});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      secondary: SettingsRowIcon(icon, color),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      leading: SettingsRowIcon(icon, color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

/// One delivery check: a tick when [ok], a warning and a Fix button when
/// not, a spinner while unknown.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.ok,
    required this.title,
    required this.problem,
    required this.onFix,
  });

  final bool? ok;
  final String title;
  final String problem;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ok = this.ok;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      leading: ok == null
          ? const SizedBox(
              width: 36,
              height: 36,
              child: Padding(
                padding: EdgeInsets.all(9),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : SettingsRowIcon(
              ok ? Icons.check : Icons.priority_high,
              ok ? palette.statusGood : palette.statusCritical,
            ),
      title: Text(title),
      subtitle: ok == false ? Text(problem) : null,
      trailing: ok == false
          ? FilledButton.tonal(onPressed: onFix, child: const Text('Fix'))
          : null,
    );
  }
}
