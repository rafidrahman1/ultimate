import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/notifications/notification_log.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/status_message.dart';

/// Unseen delivered notifications, for the bell badge in the app bar.
/// Invalidate after visiting [NotificationsScreen].
final unseenNotificationsProvider = FutureProvider.autoDispose<int>(
  (ref) => NotificationLog.unseenCount(),
);

/// Notifications the app has sent recently. Scheduled ones stay hidden until
/// they are delivered.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<LoggedNotification>? _items;

  @override
  void initState() {
    super.initState();
    _load();
    NotificationLog.markSeen();
  }

  Future<void> _load() async {
    final items = await NotificationLog.load();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _clearHistory() async {
    await NotificationLog.clearHistory();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final items = _items == null
        ? null
        : ([..._items!.where((n) => !n.isUpcoming(now))]
            ..sort((a, b) => b.at.compareTo(a.at)));

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Notifications',
        extraActions: [
          AppBarCircularAction(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Clear history',
            onPressed: (items?.isEmpty ?? true) ? null : _clearHistory,
          ),
        ],
      ),
      body: switch (items) {
        null => const Center(child: CircularProgressIndicator()),
        [] => const StatusMessage(
          icon: Icons.notifications_none_outlined,
          title: 'No notifications',
          subtitle:
              'Reminders from predictions, check-ins and advice will show '
              'up here.',
        ),
        final List<LoggedNotification> delivered => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              AppSpacing.xxl,
            ),
            children: [
              for (final n in delivered)
                _NotificationTile(notification: n, when: n.at, now: now),
            ],
          ),
        ),
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.when,
    required this.now,
  });

  final LoggedNotification notification;
  final DateTime when;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final kind = _kindFor(notification.channel);
    final repeat = notification.repeat == NotificationRepeat.weekly
        ? ' · Weekly'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(kind.icon, size: 22, color: muted),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _formatWhen(when, now),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(notification.body, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 2),
                Text(
                  '${kind.label}$repeat',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatWhen(DateTime when, DateTime now) {
  final day = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final time = DateFormat.jm().format(when);
  return switch (day.difference(today).inDays) {
    0 => 'Today $time',
    1 => 'Tomorrow $time',
    -1 => 'Yesterday $time',
    > 1 && < 7 => '${DateFormat.E().format(when)} $time',
    _ => '${DateFormat.MMMd().format(when)} $time',
  };
}

typedef _Kind = ({IconData icon, String label});

_Kind _kindFor(String? channel) => switch (channel) {
  'check_in' => (icon: Icons.mood_outlined, label: 'Daily check-in'),
  'advice_reminders' => (
    icon: Icons.lightbulb_outline,
    label: 'Advice reminder',
  ),
  'predictions_money' => (
    icon: Icons.payments_outlined,
    label: 'Money prediction',
  ),
  'predictions_bike' => (
    icon: Icons.two_wheeler_outlined,
    label: 'Bike maintenance',
  ),
  'predictions_commute' => (
    icon: Icons.directions_walk_outlined,
    label: 'Commute',
  ),
  'predictions_digest' => (
    icon: Icons.view_week_outlined,
    label: 'Weekly digest',
  ),
  'odometer' => (icon: Icons.speed_outlined, label: 'Odometer log'),
  'predictions_life' => (icon: Icons.insights_outlined, label: 'Prediction'),
  'test_notification' => (
    icon: Icons.notifications_active_outlined,
    label: 'Test',
  ),
  _ => (icon: Icons.notifications_none_outlined, label: 'Reminder'),
};
