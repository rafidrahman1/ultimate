import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Shows a dialog where the user picks a calendar month (first day of month).
Future<DateTime?> showMonthPicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _MonthPickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: helpText,
    ),
  );
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.helpText,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? helpText;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _displayYear;

  DateTime get _firstMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month, 1);

  DateTime get _lastMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month, 1);

  DateTime get _selectedMonth =>
      DateTime(widget.initialDate.year, widget.initialDate.month, 1);

  @override
  void initState() {
    super.initState();
    _displayYear = widget.initialDate.year;
  }

  bool _isMonthEnabled(int year, int month) {
    final monthStart = DateTime(year, month, 1);
    return !monthStart.isBefore(_firstMonth) && !monthStart.isAfter(_lastMonth);
  }

  bool get _canGoToPreviousYear => _displayYear > _firstMonth.year;

  bool get _canGoToNextYear => _displayYear < _lastMonth.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final monthLabels = List.generate(
      12,
      (index) => DateFormat('MMM').format(DateTime(2000, index + 1, 1)),
    );

    return AlertDialog(
      title: Text(widget.helpText ?? 'Choose month'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _canGoToPreviousYear
                      ? () => setState(() => _displayYear--)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '$_displayYear',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  onPressed:
                      _canGoToNextYear ? () => setState(() => _displayYear++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                final month = index + 1;
                final enabled = _isMonthEnabled(_displayYear, month);
                final monthStart = DateTime(_displayYear, month, 1);
                final selected =
                    enabled && monthStart == _selectedMonth;

                return FilledButton.tonal(
                  onPressed: enabled
                      ? () => Navigator.pop(context, monthStart)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: selected
                        ? colorScheme.primaryContainer
                        : null,
                    foregroundColor: selected
                        ? colorScheme.onPrimaryContainer
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(monthLabels[index]),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
