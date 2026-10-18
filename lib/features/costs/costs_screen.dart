import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/costs/expense_form.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';

/// Everything the bike costs: fuel and service from their own logs, plus the
/// other expenses logged here.
class CostsScreen extends ConsumerWidget {
  const CostsScreen({super.key, required this.bike});

  final Bike bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final theme = Theme.of(context);
    final palette = context.palette;
    final money = data.currency;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);

    final lifetime = costByCategory(data, bike);
    final thisMonth = costByCategory(data, bike, from: monthStart);
    final total = totalCost(lifetime);
    final km = latestOdometer(data, bike) - bike.startOdometer;

    // Last six months, oldest first.
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final monthly = [
      for (final m in months)
        totalCost(
          costByCategory(
            data,
            bike,
            from: m,
            to: DateTime(m.year, m.month + 1),
          ),
        ),
    ];
    final maxMonth = monthly.fold<double>(0, (a, b) => a > b ? a : b);

    final expenses = [
      for (final e in data.expenses)
        if (e.bikeId == bike.id) e,
    ]..sort((a, b) => b.date.compareTo(a.date));
    final breakdown = lifetime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
            accent: palette.expenses,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This month', style: context.sectionLabel),
                Text(
                  formatMoney(money, totalCost(thisMonth)),
                  style: context.statDisplay,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _Mini(formatMoney(money, total), 'all time'),
                    ),
                    Expanded(
                      child: _Mini(
                        km > 50
                            ? formatMoney(
                                money,
                                double.parse((total / km).toStringAsFixed(2)),
                              )
                            : '—',
                        'per km ridden',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Last 6 months', style: context.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < months.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (monthly[i] > 0)
                            FittedBox(
                              child: Text(
                                formatMoney(money, monthly[i]),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            height: maxMonth == 0
                                ? 2
                                : 2 + 70 * monthly[i] / maxMonth,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: palette.expenses,
                              borderRadius: BorderRadius.circular(AppRadii.xs),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM').format(months[i]),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Where it goes', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  for (final b in breakdown)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(b.key)),
                              Text(
                                formatMoney(money, b.value),
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.xs),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : b.value / total,
                              minHeight: 5,
                              color: palette.expenses,
                              backgroundColor: palette.border,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Other expenses', style: context.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          if (expenses.isEmpty)
            Text(
              'Insurance, gear, parking, fines — log them with the + button. '
              'Fuel and service costs are counted automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          for (final e in expenses)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                onTap: () => showExpenseForm(context, bike: bike, entry: e),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.category.label,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${DateFormat('d MMM yyyy').format(e.date)}'
                            '${e.note.isEmpty ? '' : ' · ${e.note}'}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(money, e.amount),
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

class _Mini extends StatelessWidget {
  const _Mini(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.palette.textMuted,
          ),
        ),
      ],
    );
  }
}
