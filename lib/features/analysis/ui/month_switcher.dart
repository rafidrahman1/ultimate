import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/ui/analysis_month_picker.dart';

/// Previous / next month arrows around a tappable month title (opens the
/// picker), plus a shortcut back to the current month. Drives the one shared
/// [selectedAnalysisMonthProvider].
class MonthSwitcher extends ConsumerWidget {
  const MonthSwitcher({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final month = ref.watch(selectedAnalysisMonthProvider);
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    final isCurrent = month == current;
    final notifier = ref.read(selectedAnalysisMonthProvider.notifier);
    final label = DateFormat('MMMM yyyy').format(month);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous month',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () =>
              notifier.setMonth(DateTime(month.year, month.month - 1, 1)),
        ),
        Flexible(
          child: Semantics(
            button: true,
            label: 'Month $label. Choose month',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.small),
              onTap: () => pickAnalysisMonth(context, ref),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      style ??
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: () =>
              notifier.setMonth(DateTime(month.year, month.month + 1, 1)),
        ),
        if (!isCurrent)
          TextButton(
            onPressed: () => notifier.setMonth(current),
            style: TextButton.styleFrom(
              foregroundColor: palette.accent,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
            child: const Text('Today'),
          ),
      ],
    );
  }
}
