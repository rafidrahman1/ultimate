import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'package:personal/core/theme/app_theme.dart';

/// Month calendar whose cells are tinted by how much happens each day.
/// Tapping a day selects it; tapping it again clears the selection.
class MonthHeatGrid extends StatelessWidget {
  const MonthHeatGrid({
    super.key,
    required this.month,
    required this.counts,
    required this.color,
    required this.selectedDay,
    required this.onSelect,
    this.holidays = const {},
    this.countNoun = 'events',
  });

  /// Any date in the month to show.
  final DateTime month;

  /// Items per day of month (1-based); missing days count as zero.
  final Map<int, int> counts;
  final Set<int> holidays;
  final Color color;
  final int? selectedDay;
  final ValueChanged<int?> onSelect;
  final String countNoun;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final maxCount = counts.values.fold<int>(0, math.max);
    final now = DateTime.now();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Column(
      children: [
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (context, index) {
            if (index < leading) return const SizedBox.shrink();
            final day = index - leading + 1;
            final count = counts[day] ?? 0;
            final isToday =
                now.year == month.year &&
                now.month == month.month &&
                now.day == day;
            final isSelected = selectedDay == day;
            final intensity = maxCount == 0 ? 0.0 : count / maxCount;
            final fill = count == 0
                ? Colors.transparent
                : color.withValues(alpha: 0.16 + 0.5 * intensity);
            final label =
                '${DateFormat('d MMMM').format(DateTime(month.year, month.month, day))}, '
                '${count == 0 ? 'no $countNoun' : '$count $countNoun'}'
                '${holidays.contains(day) ? ', holiday' : ''}';

            return Semantics(
              button: true,
              selected: isSelected,
              label: label,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(isSelected ? null : day);
                },
                child: AnimatedContainer(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AppRadii.small),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : isToday
                          ? palette.textSecondary
                          : count == 0
                          ? palette.border
                          : Colors.transparent,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$day',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: isToday || count > 0
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: count > 0 && intensity > 0.55
                                ? Colors.white
                                : palette.textPrimary,
                          ),
                        ),
                      ),
                      if (holidays.contains(day))
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: palette.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Text(
              DateFormat('MMMM yyyy').format(month),
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
            const Spacer(),
            if (holidays.isNotEmpty) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Holiday',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
