import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/commute_alert/commute_alert_service.dart';
import 'package:personal/features/forecasts/reminders/advice_reminder_service.dart';
import 'package:personal/features/forecasts/reminders/check_in_reminder_service.dart';
import 'package:personal/features/forecasts/reminders/notification_setup.dart';
import 'package:personal/features/forecasts/reminders/prediction_calendar_service.dart';
import 'package:personal/features/settings/widgets/commute_alert_rows.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/settings_kit.dart';

/// What this phone reminds you about, whether reminders can actually arrive,
/// and which predictions go on Google Calendar.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _checkIn = true;
  bool _calendar = false;
  Set<String> _excluded = const {};
  ReminderHealth? _health;

  @override
  void initState() {
    super.initState();
    _load();
    _checkHealth();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Fixes are made in system settings; check again on the way back.
    if (state == AppLifecycleState.resumed) _checkHealth();
  }

  Future<void> _load() async {
    final checkIn = await CheckInReminderService.isEnabled();
    final calendar = await PredictionCalendarService.isEnabled();
    final excluded = await PredictionCalendarService.excludedKeys();
    if (!mounted) return;
    setState(() {
      _checkIn = checkIn;
      _calendar = calendar;
      _excluded = excluded;
      _loading = false;
    });
  }

  Future<void> _checkHealth() async {
    final before = _health;
    final health = await NotificationSetup.health();
    if (!mounted) return;
    setState(() => _health = health);
    // Rebuild the schedule as exact alarms once they become allowed.
    if (before != null && !before.exactAlarms && health.exactAlarms) {
      await CheckInReminderService.reschedule();
      await AdviceReminderService.apply();
      await CommuteAlertService.schedule();
    }
  }

  Future<void> _setCheckIn(bool enabled) async {
    setState(() => _checkIn = enabled);
    await CheckInReminderService.setEnabled(enabled);
  }

  Future<void> _setCalendar(bool enabled) async {
    setState(() => _calendar = enabled);
    try {
      await PredictionCalendarService.setEnabled(enabled);
    } catch (error) {
      if (!mounted) return;
      setState(() => _calendar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is FormatException ? error.message : '$error'),
        ),
      );
    }
  }

  Future<void> _setCategory(String key, bool enabled) async {
    setState(
      () => _excluded = enabled
          ? ({..._excluded}..remove(key))
          : {..._excluded, key},
    );
    await PredictionCalendarService.setCategoryEnabled(key, enabled);
  }

  Future<void> _removeEvents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove app events?'),
        content: const Text(
          'Every event this app added to your Google Calendar will be '
          'deleted, and adding predictions to the calendar will be turned '
          'off.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    String message;
    try {
      final removed = await PredictionCalendarService.removeAllEvents();
      message = removed == 0
          ? 'No app events found on the calendar.'
          : 'Removed $removed ${removed == 1 ? 'event' : 'events'}.';
      if (mounted) setState(() => _calendar = false);
    } on FormatException catch (e) {
      message = e.message;
    } catch (e) {
      message = "Couldn't remove events: $e";
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendTest() async {
    await NotificationSetup.showTest(
      title: 'Test notification',
      body: 'Alerts from Personal are working.',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sent. If nothing appears, allow notifications for Personal in '
          'system settings.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final status = context.statusColors;
    final health = _health;

    final problems = health == null
        ? const <_Check>[]
        : [
            if (!health.notificationsAllowed)
              const _Check(
                'Notifications are blocked',
                'Nothing can show until they are allowed in system settings.',
                NotificationSetup.fixNotifications,
              ),
            if (!health.exactAlarms)
              const _Check(
                'On-time alarms are off',
                'Android may deliver reminders late.',
                NotificationSetup.fixExactAlarms,
              ),
            if (!health.batteryUnrestricted)
              const _Check(
                'Battery optimisation is on',
                'Reminders can be delayed or dropped while the app is closed.',
                NotificationSetup.fixBattery,
              ),
          ];

    final (String headline, Color? tone) = health == null
        ? ('Checking delivery…', null)
        : problems.isEmpty
        ? ('Reminders arrive on time', status.good)
        : (
            problems.length == 1
                ? '1 thing may stop reminders'
                : '${problems.length} things may stop reminders',
            status.warning,
          );

    final categories = PredictionCalendarService.categories;
    final included = categories.where((c) => !_excluded.contains(c.key));

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Notifications'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            SettingsPageHeader(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              status: headline,
              statusColor: tone,
              description:
                  'Reminders this phone sends, and dated predictions added to '
                  'your Google Calendar.',
              actions: [
                TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.notifications),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: const Text('Sent'),
                ),
                OutlinedButton.icon(
                  onPressed: _sendTest,
                  icon: const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                  ),
                  label: const Text('Send a test'),
                ),
              ],
            ),
            if (problems.isNotEmpty)
              SettingsGroup(
                label: 'Fix delivery',
                children: [
                  for (final check in problems)
                    SettingsTile(
                      icon: Icons.priority_high_rounded,
                      iconColor: status.warning,
                      title: check.title,
                      subtitle: check.problem,
                      trailing: FilledButton.tonal(
                        onPressed: check.fix,
                        child: const Text('Fix'),
                      ),
                    ),
                ],
              ),
            SettingsGroup(
              label: 'Reminders',
              children: [
                const CommuteAlertRows(),
                SettingsSwitchTile(
                  icon: Icons.mood_outlined,
                  iconColor: palette.health,
                  title: 'Daily check-in',
                  subtitle:
                      'At 21:00 to log mood, energy and stress. Skipped once '
                      'the day is logged.',
                  value: _checkIn,
                  onChanged: _loading ? null : _setCheckIn,
                ),
              ],
            ),
            SettingsGroup(
              label: 'Google Calendar',
              footer:
                  'All-day events, kept up to date as predictions change. '
                  'Your calendar sends their reminders.',
              children: [
                SettingsSwitchTile(
                  icon: Icons.event_outlined,
                  iconColor: palette.calendar,
                  title: 'Add predictions to calendar',
                  subtitle: _calendar
                      ? '${included.length} of ${categories.length} kinds '
                            'included'
                      : 'Off',
                  value: _calendar,
                  onChanged: _loading ? null : _setCalendar,
                ),
                if (_calendar)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      kSettingsRowInset,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final category in categories)
                          FilterChip(
                            label: Text(category.label),
                            selected: !_excluded.contains(category.key),
                            onSelected: _loading
                                ? null
                                : (on) => _setCategory(category.key, on),
                          ),
                      ],
                    ),
                  ),
                SettingsTile(
                  icon: Icons.event_busy_outlined,
                  iconColor: palette.statusCritical,
                  title: 'Remove app events',
                  subtitle:
                      'Deletes every event this app added to your calendar.',
                  enabled: !_loading,
                  onTap: _removeEvents,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A failing delivery check and how to fix it.
class _Check {
  const _Check(this.title, this.problem, this.fix);

  final String title;
  final String problem;
  final Future<void> Function() fix;
}
