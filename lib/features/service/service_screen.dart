import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/features/service/service_form.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';

/// Colour for a due level.
Color dueColor(BuildContext context, DueLevel level) {
  final palette = context.palette;
  return switch (level) {
    DueLevel.ok => palette.statusGood,
    DueLevel.soon => palette.warning,
    DueLevel.overdue => palette.statusCritical,
  };
}

/// One line saying when a task is due, e.g. "Due in 320 km · 45 days".
String dueText(TaskStatus s) {
  final parts = <String>[];
  final km = s.kmLeft;
  if (km != null) {
    parts.add(km < 0 ? '${formatKm(-km)} over' : 'in ${formatKm(km)}');
  }
  final days = s.daysLeft;
  if (days != null) {
    parts.add(days < 0 ? '${-days} days over' : 'in $days days');
  }
  final prefix = s.level == DueLevel.overdue ? 'Overdue' : 'Due';
  return '$prefix ${parts.join(' · ')}';
}

class ServiceScreen extends ConsumerWidget {
  const ServiceScreen({super.key, required this.bike});

  final Bike bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final today = DateTime.now();
    final statuses = taskStatuses(data, bike, today)
      ..sort((a, b) => b.used.compareTo(a.used));
    final history = [
      for (final s in data.services)
        if (s.bikeId == bike.id) s,
    ]..sort((a, b) => b.date.compareTo(a.date));
    final theme = Theme.of(context);
    final palette = context.palette;

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          96,
        ),
        children: [
          Text('Maintenance', style: context.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          for (final s in statuses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: () => showServiceForm(
                  context,
                  bike: bike,
                  presetTaskId: s.task.id,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 6,
                      height: 44,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: dueColor(context, s.level),
                          borderRadius: BorderRadius.circular(AppRadii.xs),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.task.name, style: theme.textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            dueText(s),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: s.level == DueLevel.ok
                                  ? palette.textSecondary
                                  : dueColor(context, s.level),
                              fontWeight: s.level == DueLevel.ok
                                  ? null
                                  : FontWeight.w700,
                            ),
                          ),
                          Text(
                            s.neverDone
                                ? 'Never logged — counting from when the bike was added'
                                : 'Last: ${DateFormat('d MMM yyyy').format(s.lastDate!)} at ${formatKm(s.lastKm!)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.xs),
                            child: LinearProgressIndicator(
                              value: s.used.clamp(0.0, 1.0),
                              minHeight: 4,
                              color: dueColor(context, s.level),
                              backgroundColor: palette.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.check_circle_outline_rounded,
                      color: palette.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Tap a job to mark it done. Edit intervals in Garage.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('History', style: context.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          if (history.isEmpty)
            Text(
              'No services logged yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          for (final e in history)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                onTap: () => showServiceForm(context, bike: bike, entry: e),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.title, style: theme.textTheme.titleSmall),
                          Text(
                            '${DateFormat('d MMM yyyy').format(e.date)} · '
                            '${formatKm(e.odometer)}'
                            '${e.shop.isEmpty ? '' : ' · ${e.shop}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (e.cost > 0)
                      Text(
                        formatMoney(data.currency, e.cost),
                        style: theme.textTheme.titleSmall,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
