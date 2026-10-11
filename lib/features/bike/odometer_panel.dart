import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/bike/odometer_service.dart';
import 'package:personal/features/expenses/fuel_forecast.dart';
import 'package:personal/features/expenses/outlook_forecast.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';

final _km = NumberFormat.decimalPattern();
final _date = DateFormat('d MMM yyyy');

/// Log the bike's odometer once a month and see what it says: km a month,
/// where the odometer will be, and how far off the next service and oil
/// change are.
class OdometerPanel extends ConsumerStatefulWidget {
  const OdometerPanel({super.key, this.service, this.oil, this.fuel});

  final BikeServiceForecast? service;
  final BikeServiceForecast? oil;
  final FuelForecast? fuel;

  @override
  ConsumerState<OdometerPanel> createState() => _OdometerPanelState();
}

class _OdometerPanelState extends ConsumerState<OdometerPanel> {
  final _controller = TextEditingController();
  DateTime _day = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _save() async {
    final km = double.tryParse(_controller.text.replaceAll(',', '').trim());
    final error = km == null
        ? 'Enter the number on the odometer.'
        : await ref.read(odometerProvider.notifier).add(_day, km);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final accent = AppSemanticColors.mobility(context);
    final log = ref.watch(odometerLogProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final latest = log.latest;
    final rate = log.perMonth;
    final legs = log.legs;
    final nowKm = log.kmAt(today, today);

    final stats = <(String, String)>[
      if (latest != null) ('${_km.format(latest.km.round())} km', 'latest'),
      if (rate != null) ('~${rate.round()} km', 'a month'),
      if (legs.isNotEmpty) ('${legs.last.km.round()} km', 'last interval'),
      if (nowKm != null && rate != null)
        ('~${_km.format((nowKm + rate).round())} km', 'in a month'),
    ];

    // Where the odometer will read when each service falls due.
    final dues = <(String, double)>[
      for (final f in [widget.service, widget.oil])
        if (f != null && f.fromOdometer && f.kmLeft != null && nowKm != null)
          (f.noun, nowKm + f.kmLeft!),
      if (widget.fuel?.distance case final d?
          when d.fromOdometer && nowKm != null)
        ('fuel refill', nowKm + d.kmLeft),
    ];
    final recent = log.readings.reversed.take(12).toList();

    return CategoryPanel(
      title: 'Bike odometer',
      trailing: latest == null ? null : 'last ${_date.format(latest.date)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stats.isNotEmpty)
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                for (final s in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.$1,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                      Text(
                        s.$2,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          if (dues.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final d in dues)
              Text(
                'Next ${d.$1} at about ${_km.format(d.$2.round())} km',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
          if (log.timelineShare != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                'Your location timeline records about '
                '${(log.timelineShare! * 100).round()}% of the km on the '
                'odometer (${log.comparedLegs.length} '
                '${log.comparedLegs.length == 1 ? 'interval' : 'intervals'} '
                'compared). Estimates since your last reading use the '
                'timeline, corrected for that gap.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            log.canMeasure
                ? 'Service, oil and next-fuel timing now use these readings '
                      'instead of recorded rides.'
                : 'Log it once a month. With two readings, service and oil '
                      'timing and the next-fuel date use your real km instead of recorded rides.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Odometer (km)',
                    errorText: _error,
                    isDense: true,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: _pickDay,
                icon: const Icon(Icons.event_rounded, size: 18),
                label: Text(DateFormat('d MMM').format(_day)),
              ),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final r in recent)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _date.format(r.date),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${_km.format(r.km.round())} km',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete reading',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        ref.read(odometerProvider.notifier).remove(r),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
