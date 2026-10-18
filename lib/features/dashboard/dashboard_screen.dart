import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/fuel/fuel_form.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/features/papers/papers_screen.dart';
import 'package:motohealth/features/service/service_form.dart';
import 'package:motohealth/features/service/service_screen.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';
import 'package:motohealth/shared/widgets/ring_gauge.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.bike, required this.goTo});

  final Bike bike;

  /// Switches the shell to another tab.
  final ValueChanged<int> goTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final theme = Theme.of(context);
    final palette = context.palette;
    final today = DateTime.now();

    final odo = estimatedOdometer(data, bike, today);
    final rate = dailyRate(data, bike, today);
    final tasks = taskStatuses(data, bike, today);
    final papers = [
      for (final p in data.papers)
        if (p.bikeId == bike.id) p,
    ];
    final score = healthScore(tasks, papers, today);
    final scoreColor = score >= 80
        ? palette.statusGood
        : score >= 50
        ? palette.warning
        : palette.statusCritical;

    final attentionTasks = [
      for (final t in tasks)
        if (t.level != DueLevel.ok) t,
    ]..sort((a, b) => b.used.compareTo(a.used));
    final attentionPapers = [
      for (final p in papers)
        if (paperLevel(p, today) != PaperLevel.valid) p,
    ]..sort((a, b) => a.expiry.compareTo(b.expiry));

    final upcoming = [
      for (final t in tasks)
        if (t.level == DueLevel.ok) t,
    ]..sort((a, b) => b.used.compareTo(a.used));

    final stats = fuelStats([
      for (final f in data.fuel)
        if (f.bikeId == bike.id) f,
    ]);
    final month = costByCategory(
      data,
      bike,
      from: DateTime(today.year, today.month),
    );

    Widget tile(String value, String label, IconData icon, Color color) {
      return Expanded(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          180,
        ),
        children: [
          AppCard(
            tier: AppCardTier.hero,
            accent: scoreColor,
            child: Row(
              children: [
                RingGauge(
                  percent: score.toDouble(),
                  color: scoreColor,
                  label: 'Bike health',
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bike health', style: context.sectionLabel),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(formatKm(odo), style: context.statDisplay),
                      ),
                      Text(
                        rate == null
                            ? 'Log a few readings to see your pace'
                            : '~${(rate * 30.4).round()} km a month',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        attentionTasks.isEmpty && attentionPapers.isEmpty
                            ? 'Everything is up to date'
                            : '${attentionTasks.length + attentionPapers.length} '
                                  'need${attentionTasks.length + attentionPapers.length == 1 ? 's' : ''} attention',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (attentionTasks.isNotEmpty || attentionPapers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Needs attention', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            for (final t in attentionTasks)
              _AttentionRow(
                icon: Icons.build_rounded,
                color: dueColor(context, t.level),
                title: t.task.name,
                detail: dueText(t),
                onTap: () => showServiceForm(
                  context,
                  bike: bike,
                  presetTaskId: t.task.id,
                ),
              ),
            for (final p in attentionPapers)
              _AttentionRow(
                icon: Icons.description_outlined,
                color: paperColor(context, paperLevel(p, today)),
                title: p.type.label,
                detail: paperText(p, today),
                onTap: () => goTo(4),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              tile(
                stats.averageKmPerLitre == null
                    ? '—'
                    : '${stats.averageKmPerLitre!.toStringAsFixed(1)} km/l',
                'mileage',
                Icons.local_gas_station_rounded,
                palette.mobility,
              ),
              const SizedBox(width: AppSpacing.sm),
              tile(
                formatMoney(data.currency, totalCost(month)),
                'spent this month',
                Icons.payments_outlined,
                palette.expenses,
              ),
            ],
          ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Coming up', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            for (final t in upcoming.take(3))
              _AttentionRow(
                icon: Icons.schedule_rounded,
                color: palette.textSecondary,
                title: t.task.name,
                detail: _comingUp(t, rate, today),
                onTap: () => goTo(2),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showFuelForm(context, bike: bike),
                  icon: const Icon(Icons.local_gas_station_rounded),
                  label: const Text('Fill-up'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showServiceForm(context, bike: bike),
                  icon: const Icon(Icons.build_rounded),
                  label: const Text('Service'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _comingUp(TaskStatus t, double? rate, DateTime today) {
    final date = expectedDueDate(t, rate, today);
    final km = t.kmLeft;
    return [
      if (km != null) 'in ${formatKm(km)}',
      if (date != null) '~${DateFormat('d MMM yyyy').format(date)}',
    ].join(' · ');
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
