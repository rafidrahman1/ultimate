import 'package:personal/features/expenses/ai_ledger_text.dart';
import 'package:personal/features/expenses/recurring_forecast.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_math.dart';

/// Raw ledger rows for the money forecasts.

/// Each recurring bill with its last payments.
String billRows(LifeInputs i) {
  final charges = forecastRecurringCharges(
    i.ledger,
    now: i.now,
    horizonDays: 45,
  );
  if (charges.isEmpty) return '- no recurring bills found';
  final out = StringBuffer();
  for (final c in charges.take(15)) {
    final key = labelKey(c.label);
    out
      ..writeln(
        '${c.label} (${c.cadence}, usually ${c.amount.round()}, '
        'next expected ${dateLine.format(c.expectedDate)}):',
      )
      ..writeln(
        entryRows(
          i.ledger,
          (t) =>
              t.isRealExpense &&
              labelKey(t.title ?? '').isNotEmpty &&
              labelKey(t.title ?? '') == key,
          limit: 8,
        ),
      );
  }
  return out.toString().trimRight();
}

String labelKey(String label) =>
    label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
