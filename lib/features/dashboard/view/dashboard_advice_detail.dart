import 'package:clock/clock.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/results/pipeline/cross_analysis.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _h(double? v) => v == null ? '-' : v.toStringAsFixed(1);

String _int(double? v) => v == null ? '-' : v.round().toString();

/// Curated day-by-day detail for the AI advice prompt: one row per day that
/// has any data, then the largest expenses and the late arrivals with the
/// sleep that preceded them. Plain numbers and short labels so a model can
/// read it reliably.
String buildAdviceDetail({
  required AnalysisPeriod period,
  required CrossInputs inputs,
  required ExpensesSummary expenses,
}) {
  final out = StringBuffer();
  final today = _day(clock.now());
  final start = _day(period.dataMonthStart);
  final endRaw = _day(period.dataMonthEnd);
  final end = endRaw.isAfter(today) ? today : endRaw;
  final weekday = DateFormat('EEE d');

  final rows = <String>[];
  for (
    var d = start;
    !d.isAfter(end);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final sleep = inputs.sleepHours[d];
    final steps = inputs.steps[d];
    final screen = inputs.screenHours[d];
    final game = inputs.gamingHours[d];
    final spend = inputs.spend[d];
    final work = inputs.lateDays.contains(d)
        ? 'late'
        : inputs.onTimeDays.contains(d)
        ? 'on-time'
        : null;
    if (sleep == null &&
        steps == null &&
        screen == null &&
        (game ?? 0) == 0 &&
        (spend ?? 0) == 0 &&
        work == null) {
      continue;
    }
    rows.add(
      '${weekday.format(d)} | ${_h(sleep)} | ${_int(steps)} | ${_h(screen)} | '
      '${_h(game)} | ${_int(spend)} | ${work ?? '-'}',
    );
  }
  if (rows.isNotEmpty) {
    out
      ..writeln(
        '[Day by day] sleep = hours slept the night before, '
        'screen/game = hours, spend in ${inputs.currency}, "-" = no data',
      )
      ..writeln('day | sleep h | steps | screen h | game h | spend | work')
      ..writeAll(rows, '\n')
      ..writeln();
  }

  final late = [
    for (final d in inputs.lateDays)
      '${weekday.format(d)} (slept ${_h(inputs.sleepHours[d])}h)',
  ];
  if (late.isNotEmpty) {
    out.writeln('\n[Late arrivals] ${late.join(', ')}');
  }

  final big =
      expenses.transactions
          .where(
            (t) =>
                t.isRealExpense &&
                !t.date.isBefore(period.dataMonthStart) &&
                !t.date.isAfter(period.dataMonthEnd),
          )
          .toList()
        ..sort((a, b) => a.amount.compareTo(b.amount));
  if (big.isNotEmpty) {
    out.writeln('\n[Largest expenses]');
    for (final t in big.take(8)) {
      final title = t.displayTitle.trim();
      out.writeln(
        '${DateFormat('EEE d').format(t.date.toLocal())} | '
        '${(-t.amount).round()} ${t.currency} | ${t.category ?? '-'}'
        '${title.isEmpty ? '' : ' | $title'}',
      );
    }
  }
  return out.toString().trimRight();
}
