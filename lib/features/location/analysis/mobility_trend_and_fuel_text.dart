part of 'mobility_prompt_builder.dart';

String? buildMobilityTrendText({
  required WorkArrivalStats current,
  WorkArrivalStats? previous,
}) {
  final currentRate = current.lateArrivalRate;
  if (currentRate == null) return null;

  final buffer = StringBuffer('Mobility Trend:')
    ..writeln()
    ..writeln(
      '- Current late arrival rate: '
      '${_formatLateArrivalRate(current.lateArrivalCount, current.totalWorkDays)}',
    );

  final previousRate = previous?.lateArrivalRate;
  if (previousRate == null || (previous?.totalWorkDays ?? 0) <= 0) {
    buffer.writeln('- Previous late arrival rate: not available');
    return buffer.toString().trimRight();
  }

  final change = currentRate - previousRate;
  final trend = trendForLowerIsBetter(
    absoluteChange: change,
    stableThreshold: 0.5,
  );

  buffer
    ..writeln(
      '- Previous late arrival rate: '
      '${_formatLateArrivalRate(previous!.lateArrivalCount, previous.totalWorkDays)}',
    )
    ..writeln('- Change: ${formatSignedPercentagePointsChange(change)}')
    ..writeln('- Trend: ${formatTrendLabel(trend)}');

  return buffer.toString().trimRight();
}

void _writeFuel(StringBuffer buffer, MobilityFuelSummary fuel) {
  buffer
    ..writeln()
    ..writeln('Fuel:')
    ..writeln(
      '- Total fuel spend: ${formatExpenseMoney(fuel.totalSpend)} '
      '${fuel.currency}',
    )
    ..writeln('- Refuels: ${fuel.refuelCount}');

  final rates = fuel.refuels
      .map((refuel) => refuel.ratePerLitre)
      .whereType<double>()
      .toList();
  if (rates.isNotEmpty) {
    final averageRate = rates.reduce((a, b) => a + b) / rates.length;
    buffer.writeln(
      '- Average fuel rate: '
      '${formatExpenseMoney(averageRate, alwaysTwoDecimals: true)} '
      '${fuel.currency}/L',
    );
  }

  if (fuel.refuels.isEmpty) return;

  buffer.writeln('Refuels:');
  for (final refuel in fuel.refuels) {
    final rateSuffix = refuel.ratePerLitre == null
        ? ''
        : ' @ ${formatExpenseMoney(refuel.ratePerLitre!, alwaysTwoDecimals: true)} '
              '${fuel.currency}/L';
    buffer.writeln(
      '- ${formatMobilityDate(refuel.date)}: '
      '${formatExpenseMoney(refuel.amount, alwaysTwoDecimals: true)} '
      '${fuel.currency}$rateSuffix',
    );
  }
}

String _formatLateArrivalRate(int lateArrivals, int workdays) {
  if (workdays <= 0) return '0.0%';
  final percent = lateArrivals / workdays * 100;
  return formatPercent1dp(percent);
}

String formatMobilityDate(DateTime date) =>
    DateFormat('d MMM').format(date.toLocal());

String formatMobilityTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String buildLateArrivalCorrelationText({
  required WorkArrivalStats workStats,
  required List<DailySleepEntry> dailySleep,
}) {
  if (workStats.lateArrivals.isEmpty) return '';

  final sleepByWakeDate = {
    for (final night in dailySleep.where((night) => night.hasData))
      _wakeDateKey(night.wakeDate): night,
  };

  var precededByShortSleep = 0;
  for (final arrival in workStats.lateArrivals) {
    final wakeKey = _wakeDateKey(arrival.date);
    final night = sleepByWakeDate[wakeKey];
    final isShort =
        night != null && night.session!.duration < sleepTargetDuration;
    if (isShort) precededByShortSleep++;
  }

  final total = workStats.lateArrivals.length;
  final correlation = total > 0 ? precededByShortSleep / total * 100 : 0.0;

  return '''
Sleep-Mobility Correlation:

- Total late arrivals: $total
- Late arrivals preceded by short sleep: $precededByShortSleep
- Correlation: ${roundTo1dp(correlation)}%'''
      .trimRight();
}

String _wakeDateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year}-${local.month}-${local.day}';
}

MobilityFuelSummary? mobilityFuelSummaryFromExpenses(ExpensesSummary expenses) {
  final fuelTransactions =
      expenses.transactions
          .where((tx) => tx.isRealExpense && ExpensesSummary.isFuelExpense(tx))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  if (fuelTransactions.isEmpty) return null;

  final refuels = fuelTransactions
      .map(
        (tx) => MobilityFuelRefuel(
          date: tx.date,
          amount: tx.amount.abs(),
          ratePerLitre: ExpensesSummary.fuelRatePerLitreFromDescription(tx),
          description: tx.note?.trim().isNotEmpty == true
              ? tx.note!.trim()
              : tx.title?.trim(),
        ),
      )
      .toList();

  return MobilityFuelSummary(
    totalSpend: refuels.fold(0.0, (sum, refuel) => sum + refuel.amount),
    refuelCount: refuels.length,
    currency: expenses.currency,
    refuels: refuels,
  );
}
