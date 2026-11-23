import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/notifications/notification_log.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/status_message.dart';

/// Unseen delivered notifications, for the bell badge in the app bar.
/// Invalidate after visiting [NotificationsScreen].
final unseenNotificationsProvider = FutureProvider.autoDispose<int>(
  (ref) => NotificationLog.unseenCount(),
);

/// Notifications the app has sent recently, grouped by day and filterable by
/// kind. Scheduled ones stay hidden until they are delivered; ones that
/// arrived since the last visit are marked as new.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<LoggedNotification>? _items;
  DateTime? _seenBefore;
  _Group? _filter;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _seenBefore = await NotificationLog.lastSeen();
    await _load();
    await NotificationLog.markSeen();
  }

  Future<void> _load() async {
    final items = await NotificationLog.load();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear notifications?'),
        content: const Text('Every notification listed here will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await NotificationLog.clearHistory();
    await _load();
  }

  bool _isNew(LoggedNotification n) {
    final seen = _seenBefore;
    return seen == null || n.at.isAfter(seen);
  }

  @override
  Widget build(BuildContext context) {
    final now = clock.now();
    final delivered = _items == null
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
            tooltip: 'Clear all',
            onPressed: (delivered?.isEmpty ?? true) ? null : _clearHistory,
          ),
        ],
      ),
      body: switch (delivered) {
        null => const Center(child: CircularProgressIndicator()),
        [] => const StatusMessage(
          icon: Icons.notifications_none_outlined,
          title: 'No notifications',
          subtitle:
              'Leave-for-work, check-in and advice reminders will show up '
              'here once they are sent.',
        ),
        final List<LoggedNotification> all => RefreshIndicator(
          onRefresh: _load,
          child: _buildList(context, all, now),
        ),
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<LoggedNotification> all,
    DateTime now,
  ) {
    final groups = {for (final n in all) _kindFor(n.channel).group};
    final filter = groups.contains(_filter) ? _filter : null;
    final shown = filter == null
        ? all
        : all.where((n) => _kindFor(n.channel).group == filter).toList();
    final newCount = all.where(_isNew).length;

    // Newest day first; within a day newest first (already sorted).
    final days = <DateTime, List<LoggedNotification>>{};
    for (final n in shown) {
      days.putIfAbsent(DateUtils.dateOnly(n.at), () => []).add(n);
    }

    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        Text(
          newCount == 0
              ? '${all.length} in the last 30 days'
              : '$newCount new · ${all.length} in the last 30 days',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
        if (groups.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                _chip('All', all.length, filter == null, () {
                  setState(() => _filter = null);
                }),
                for (final g in _Group.values)
                  if (groups.contains(g))
                    _chip(
                      g.label,
                      all.where((n) => _kindFor(n.channel).group == g).length,
                      filter == g,
                      () => setState(() => _filter = g),
                    ),
              ],
            ),
          ),
        ],
        for (final MapEntry(key: day, value: items) in days.entries) ...[
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              _dayLabel(day, now).toUpperCase(),
              style: context.sectionLabel.copyWith(color: muted),
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 64,
                      color: context.palette.border,
                    ),
                  _NotificationTile(
                    notification: items[i],
                    isNew: _isNew(items[i]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(String label, int count, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text('$label  $count'),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.isNew});

  final LoggedNotification notification;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final muted = theme.colorScheme.onSurfaceVariant;
    final kind = _kindFor(notification.channel);
    final color = kind.color(palette);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: AppOpacity.medium),
              shape: BoxShape.circle,
            ),
            child: Icon(kind.icon, size: 18, color: color),
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
                        kind.label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                    Text(
                      DateFormat.jm().format(notification.at),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    if (isNew) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Semantics(
                        label: 'New',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  notification.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isNew ? FontWeight.w700 : null,
                  ),
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dayLabel(DateTime day, DateTime now) {
  final today = DateUtils.dateOnly(now);
  return switch (today.difference(day).inDays) {
    0 => 'Today',
    1 => 'Yesterday',
    > 1 && < 7 => DateFormat.EEEE().format(day),
    _ when day.year == now.year => DateFormat.MMMMEEEEd().format(day),
    _ => DateFormat.yMMMEd().format(day),
  };
}

/// Filter groups, in chip order.
enum _Group {
  commute('Commute'),
  checkIn('Check-in'),
  advice('Advice'),
  predictions('Predictions'),
  other('Other');

  const _Group(this.label);

  final String label;
}

typedef _Kind = ({
  IconData icon,
  String label,
  _Group group,
  Color Function(AppPalette) color,
});

_Kind _kindFor(String? channel) => switch (channel) {
  'predictions_commute' => (
    icon: Icons.directions_walk_outlined,
    label: 'Commute',
    group: _Group.commute,
    color: (p) => p.mobility,
  ),
  'check_in' => (
    icon: Icons.mood_outlined,
    label: 'Daily check-in',
    group: _Group.checkIn,
    color: (p) => p.health,
  ),
  'advice_reminders' => (
    icon: Icons.lightbulb_outline,
    label: 'Advice',
    group: _Group.advice,
    color: (p) => p.warning,
  ),
  // Kinds below are no longer sent but may still be in recent history.
  'predictions_money' => (
    icon: Icons.payments_outlined,
    label: 'Money prediction',
    group: _Group.predictions,
    color: (p) => p.expenses,
  ),
  'predictions_bike' => (
    icon: Icons.two_wheeler_outlined,
    label: 'Bike maintenance',
    group: _Group.predictions,
    color: (p) => p.mobility,
  ),
  'predictions_digest' => (
    icon: Icons.view_week_outlined,
    label: 'Weekly digest',
    group: _Group.predictions,
    color: (p) => p.calendar,
  ),
  'odometer' => (
    icon: Icons.speed_outlined,
    label: 'Odometer log',
    group: _Group.predictions,
    color: (p) => p.mobility,
  ),
  'predictions_life' => (
    icon: Icons.insights_outlined,
    label: 'Prediction',
    group: _Group.predictions,
    color: (p) => p.calendar,
  ),
  'test_notification' => (
    icon: Icons.notifications_active_outlined,
    label: 'Test',
    group: _Group.other,
    color: (p) => p.statusNeutral,
  ),
  _ => (
    icon: Icons.notifications_none_outlined,
    label: 'Reminder',
    group: _Group.other,
    color: (p) => p.statusNeutral,
  ),
};
