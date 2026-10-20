import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/fuel/fuel_form.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';
import 'package:motohealth/shared/widgets/status_message.dart';

class FuelScreen extends ConsumerWidget {
  const FuelScreen({super.key, required this.bike});

  final Bike bike;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final entries = [
      for (final f in data.fuel)
        if (f.bikeId == bike.id) f,
    ]..sort((a, b) => b.date.compareTo(a.date));
    if (entries.isEmpty) {
      return const StatusMessage(
        icon: Icons.local_gas_station_rounded,
        title: 'No fill-ups yet',
        subtitle:
            'Log each refuel with the odometer and litres. Fill the tank '
            'to the top each time and mileage works itself out.',
      );
    }

    final stats = fuelStats(entries);
    final theme = Theme.of(context);
    final palette = context.palette;
    final money = data.currency;
    final kmpl = stats.averageKmPerLitre;
    final perKm = stats.costPerKm;

    Widget stat(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: context.statDisplay.copyWith(fontSize: 22),
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
    );

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
            accent: palette.mobility,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    stat(
                      kmpl == null ? '—' : '${kmpl.toStringAsFixed(1)} km/l',
                      'average mileage',
                    ),
                    stat(
                      stats.lastKmPerLitre == null
                          ? '—'
                          : '${stats.lastKmPerLitre!.toStringAsFixed(1)} km/l',
                      'last tank',
                    ),
                    stat(
                      stats.bestKmPerLitre == null
                          ? '—'
                          : '${stats.bestKmPerLitre!.toStringAsFixed(1)} km/l',
                      'best tank',
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    stat(
                      perKm == null
                          ? '—'
                          : formatMoney(
                              money,
                              double.parse(perKm.toStringAsFixed(2)),
                            ),
                      'fuel cost per km',
                    ),
                    stat(formatMoney(money, stats.totalCost), 'spent on fuel'),
                    stat(
                      '${stats.totalLitres.toStringAsFixed(0)} L',
                      'bought in ${stats.fills} fills',
                    ),
                  ],
                ),
                if (kmpl == null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      'Mileage needs two full-tank fill-ups.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('History', style: context.sectionLabel),
          const SizedBox(height: AppSpacing.sm),
          for (final e in entries)
            _FuelTile(
              entry: e,
              money: money,
              kmPerLitre: [
                for (final s in stats.segments)
                  if (s.endDate == e.date) s.kmPerLitre,
              ].firstOrNull,
              onTap: () => showFuelForm(context, bike: bike, entry: e),
            ),
        ],
      ),
    );
  }
}

class _FuelTile extends StatelessWidget {
  const _FuelTile({
    required this.entry,
    required this.money,
    required this.kmPerLitre,
    required this.onTap,
  });

  final FuelEntry entry;
  final String money;
  final double? kmPerLitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('d MMM yyyy').format(entry.date),
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    '${entry.litres.toStringAsFixed(2)} L'
                    '${entry.fuelType == null ? '' : ' ${entry.fuelType!.label}'}'
                    '${entry.odometer == null ? '' : ' at ${formatKm(entry.odometer!)}'}'
                    '${entry.fullTank ? '' : ' · partial'}'
                    '${entry.station.isEmpty ? '' : ' · ${entry.station}'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(money, entry.cost),
                  style: theme.textTheme.titleSmall,
                ),
                if (kmPerLitre != null)
                  Text(
                    '${kmPerLitre!.toStringAsFixed(1)} km/l',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.statusGood,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
