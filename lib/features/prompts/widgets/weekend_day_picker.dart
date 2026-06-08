import 'package:flutter/material.dart';

import 'package:personal/core/weekday_schedule.dart';

class WeekendDayPicker extends StatelessWidget {
  const WeekendDayPicker({
    super.key,
    required this.selectedWeekdays,
    required this.onChanged,
    this.label = 'Weekend days',
    this.helperText,
  });

  final Set<int> selectedWeekdays;
  final ValueChanged<Set<int>> onChanged;
  final String label;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final weekday in weekdayDisplayOrder)
              FilterChip(
                label: Text(weekdayShortLabel(weekday)),
                selected: selectedWeekdays.contains(weekday),
                onSelected: (selected) {
                  final next = Set<int>.from(selectedWeekdays);
                  if (selected) {
                    next.add(weekday);
                  } else {
                    next.remove(weekday);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}
