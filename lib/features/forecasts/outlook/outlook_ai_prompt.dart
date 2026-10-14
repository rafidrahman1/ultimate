part of 'outlook_ai.dart';

String buildOutlookAiPrompt({
  required DateTime now,
  required String currency,
  required Iterable<CalendarEvent> events,
  required List<UpcomingCharge> bills,
  MonthProjection? monthPace,
  BudgetOutlook? budget,
  PaydayOutlook? payday,
  BikeServiceForecast? bike,
  BikeServiceForecast? oil,
  String? rideContext,
  List<MonthlyExpenseRow> history = const [],
  Iterable<CashewTransaction> transactions = const [],
  Iterable<CashewTransaction> spending = const [],
  Iterable<TimelineActivity> activities = const [],
  Set<OutlookSection> sections = const {...OutlookSection.values},
}) {
  bool asked(OutlookSection s) => sections.contains(s);
  final fmt = DateFormat('yyyy-MM-dd (EEE)');
  final today = DateTime(now.year, now.month, now.day);
  final out = StringBuffer()
    ..writeln('Today: ${fmt.format(today)}')
    ..writeln('Currency: $currency');
  final schema = <String>[];

  if (monthPace != null && asked(OutlookSection.budget)) {
    out
      ..writeln()
      ..writeln('This month so far:')
      ..writeln(
        '- Spent ${monthPace.spentSoFar.round()} on day '
        '${monthPace.daysElapsed} of ${monthPace.daysInMonth}',
      )
      ..writeln('- A normal month is ${monthPace.typicalMonth.round()}')
      ..writeln(
        '- Baseline month-end total: ${monthPace.projected.round()} '
        '(spent so far + a normal day for each day left)',
      );
    final recent = history.length > 6
        ? history.sublist(history.length - 6)
        : history;
    if (recent.isNotEmpty) {
      out.writeln(
        '- Past months: '
        '${recent.map((m) => '${DateFormat('MMM').format(m.month)} ${m.spend.round()}').join(', ')}',
      );
    }
    out
      ..writeln()
      ..writeln('Daily spending, last 120 days (raw):')
      ..writeln(dailySpendRows(spending, now));
  }

  if (budget != null && asked(OutlookSection.budget)) {
    out
      ..writeln()
      ..writeln('Budget: ${budget.budget.round()} for the month')
      ..writeln(
        budget.isOver
            ? '- Already used up'
            : budget.runoutDate == null
            ? '- Baseline: lasts the month'
            : '- Baseline: runs out ${fmt.format(budget.runoutDate!)}',
      );
    schema.add(
      '"budget":{"runout_date":"YYYY-MM-DD or null if it lasts the month",'
      '"reasoning":"<one sentence>"}',
    );
  }

  if (bills.isNotEmpty && asked(OutlookSection.bills)) {
    out
      ..writeln()
      ..writeln('Bills expected in the next 30 days (baseline):');
    for (final b in bills.take(12)) {
      out.writeln(
        '- ${b.label}: ${b.amount.round()} ${b.cadence}, due '
        '${fmt.format(b.expectedDate)} (last paid ${fmt.format(b.lastDate)}, '
        '${b.count} times)',
      );
      final key = _labelKey(b.label);
      out.writeln(
        entryRows(transactions, (t) {
          final title = _labelKey(t.displayTitle);
          return t.isRealExpense &&
              title.isNotEmpty &&
              (title == key || title.contains(key) || key.contains(title));
        }, limit: 12),
      );
    }
    schema.add(
      '"bills":{"items":[{"label":"<exact label>","expected_date":"YYYY-MM-DD",'
      '"amount":<number>}],"reasoning":"<one sentence>"}',
    );
  }

  if (payday != null && asked(OutlookSection.payday)) {
    out
      ..writeln()
      ..writeln(
        'Next income: ${payday.label} about ${payday.amount.round()}, '
        'baseline ${fmt.format(payday.expectedDate)}',
      )
      ..writeln(
        '- Baseline spending until then: ${payday.expectedSpend.round()}',
      )
      ..writeln('Income entries, last 12 months (raw):')
      ..writeln(incomeRows(transactions, now));
    schema.add(
      '"payday":{"date":"YYYY-MM-DD","spend_until":<number>,'
      '"reasoning":"<one sentence>"}',
    );
  }

  void maintenance(
    BikeServiceForecast? f,
    OutlookSection section,
    String title,
    String key,
  ) {
    if (f == null || !asked(section)) return;
    out
      ..writeln()
      ..writeln('$title:')
      ..writeln(
        '- Last ${f.noun} ${fmt.format(f.lastDone)}, ${f.count} on record',
      );
    if (f.hasRiding) {
      out
        ..writeln('- ${f.kmSince.round()} km ridden since')
        ..writeln('- Riding lately ${f.dailyKm.toStringAsFixed(1)} km/day');
    }
    if (f.intervalKm != null) {
      out.writeln(
        '- Usual interval ${f.intervalKm!.round()} km, '
        '${f.kmLeft!.round()} km left',
      );
    }
    if (f.intervalDays != null) {
      out.writeln('- Usual gap ${f.intervalDays} days');
    }
    if (f.expectedDate != null) {
      out.writeln('- Baseline due ${fmt.format(f.expectedDate!)}');
    }
    final category = f.category;
    if (category != null) {
      out
        ..writeln('- These entries are filed under the category "$category"')
        ..writeln('Entries in that category (raw):')
        ..writeln(
          entryRows(
            transactions,
            (t) => t.isRealExpense && (t.category?.trim() ?? '') == category,
          ),
        );
    }
    out.writeln(
      '- An entry\'s note often holds the bike\'s odometer reading on that '
      'day (e.g. "12,450 km"). Where present, treat it as exact: the '
      'difference between notes is the real km between entries, and the '
      'km ridden since the last entry is already counted from it.',
    );
    out
      ..writeln('Motorcycle km per day, last 120 days (raw):')
      ..writeln(dailyKmRows(activities, now));
    final about = rideContext?.trim() ?? '';
    out.writeln(
      about.isEmpty
          ? '- The rider has not said what vehicle they ride.'
          : '- The rider\'s ride, from their personal info: '
                '"${about.length > 600 ? '${about.substring(0, 600)}…' : about}"',
    );
    out.writeln(
      '- Work out which vehicle this is from the category and the personal '
      'info. Use that vehicle\'s usual ${f.noun} interval (km and months) '
      'together with the km ridden since the last one and the recent riding '
      'to set the date. If the vehicle is unclear, assume a typical '
      'scooter or motorcycle.',
    );
    if (f.expectedDate == null && f.intervalKm == null) {
      out.writeln(
        '- No usual interval from their own history yet (too little '
        'history), so the vehicle\'s usual interval matters most.',
      );
    }
    schema.add(
      '"$key":{"date":"YYYY-MM-DD","reasoning":"<one sentence naming the '
      'vehicle and the interval you used>"}',
    );
  }

  maintenance(bike, OutlookSection.bike, 'Bike service', 'bike_service');
  maintenance(oil, OutlookSection.oil, 'Engine oil change', 'oil_change');

  final horizon = today.add(const Duration(days: 30));
  final upcoming = events.where((e) {
    final start = DateTime(e.start.year, e.start.month, e.start.day);
    return !start.isBefore(today) && !start.isAfter(horizon);
  }).toList()..sort((a, b) => a.start.compareTo(b.start));
  out
    ..writeln()
    ..writeln('Calendar events, next 30 days:');
  if (upcoming.isEmpty) {
    out.writeln('- none');
  } else {
    for (final e in upcoming.take(30)) {
      final tags = [
        if (e.isHoliday) 'holiday',
        if (e.allDay) 'all day',
        if (e.location != null && e.location!.trim().isNotEmpty)
          'at ${e.location!.trim()}',
      ];
      out.writeln(
        '- ${fmt.format(e.start)}: ${e.title}'
        '${tags.isEmpty ? '' : ' (${tags.join(', ')})'}',
      );
    }
  }

  out
    ..writeln()
    ..writeln('Return JSON with only these keys: {${schema.join(',')}}');
  return out.toString();
}
