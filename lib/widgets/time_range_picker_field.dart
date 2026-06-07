import 'package:flutter/material.dart';

import '../core/time_range_schedule.dart';

class TimeRangePickerField extends StatelessWidget {
  const TimeRangePickerField({
    super.key,
    required this.label,
    required this.start,
    required this.end,
    required this.onChanged,
    this.helperText,
  });

  final String label;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final void Function(TimeOfDay? start, TimeOfDay? end) onChanged;
  final String? helperText;

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? start : end) ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    if (isStart) {
      onChanged(picked, end);
    } else {
      onChanged(start, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = formatTimeRange(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            helperText: helperText,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (summary.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    summary,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(context, isStart: true),
                      child: Text(
                        start == null ? 'Start time' : formatTimeLabel(start!),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('to'),
                  ),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickTime(context, isStart: false),
                      child: Text(
                        end == null ? 'End time' : formatTimeLabel(end!),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
