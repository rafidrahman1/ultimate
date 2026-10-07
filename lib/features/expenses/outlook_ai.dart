import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/expenses/ai_ledger_text.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_insights.dart';
import 'package:personal/features/expenses/outlook_forecast.dart';
import 'package:personal/features/expenses/recurring_forecast.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// A date from the reply. The prompt shows dates as "2026-10-22 (Thu)", so
/// models often echo the weekday back; the first ISO date in the text wins,
/// then a few written-out formats.
DateTime? _date(Object? v) {
  if (v is! String) return null;
  final text = v.trim();
  var parsed = DateTime.tryParse(
    RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(text)?.group(0) ?? text,
  );
  if (parsed == null) {
    for (final pattern in const [
      'd MMM yyyy',
      'd MMMM yyyy',
      'MMM d, yyyy',
      'MMMM d, yyyy',
      'dd/MM/yyyy',
    ]) {
      try {
        parsed = DateFormat(pattern).parseLoose(text);
        break;
      } on FormatException {
        continue;
      }
    }
  }
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

/// A positive amount, from a number or text like "1,200" or "৳1200".
double? _positive(Object? v) {
  final value = v is num
      ? v.toDouble()
      : v is String
      ? double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''))
      : null;
  return value != null && value > 0 ? value : null;
}

String _labelKey(String label) =>
    label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _note(Object? v) => v is String ? v.trim() : '';

/// A bill the model moved or re-priced.
class BillAi {
  const BillAi({
    required this.label,
    required this.expectedDate,
    required this.amount,
  });

  factory BillAi.fromJson(Map<String, dynamic> j) => BillAi(
    label: j['label'] as String,
    expectedDate: DateTime.parse(j['expectedDate'] as String),
    amount: (j['amount'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'expectedDate': expectedDate.toIso8601String(),
    'amount': amount,
  };

  final String label;
  final DateTime expectedDate;
  final double amount;
}

/// Which prediction an AI refinement is for. Each is refined on its own.
enum OutlookSection { bills, monthEnd, budget, payday, bike, oil }

/// The model's reading of the non-fuel predictions. Each section is refined
/// separately, so a section never refined, or one the model got wrong, is
/// simply absent from [refinedAt].
class OutlookAiEstimate {
  const OutlookAiEstimate({
    this.refinedAt = const {},
    this.bills = const [],
    this.billsNote = '',
    this.monthEnd,
    this.monthEndNote = '',
    this.hasBudget = false,
    this.budgetRunout,
    this.budgetNote = '',
    this.payday,
    this.paydaySpend,
    this.paydayNote = '',
    this.bikeServiceDate,
    this.bikeNote = '',
    this.oilChangeDate,
    this.oilNote = '',
  });

  factory OutlookAiEstimate.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) =>
        j[k] == null ? null : DateTime.parse(j[k] as String);
    final stamps = <OutlookSection, DateTime>{};
    final rawStamps = j['refinedAt'];
    if (rawStamps is Map) {
      for (final s in OutlookSection.values) {
        final v = rawStamps[s.name];
        if (v is String) stamps[s] = DateTime.parse(v);
      }
    }
    return OutlookAiEstimate(
      refinedAt: stamps,
      bills: [
        for (final b in (j['bills'] as List? ?? const []))
          BillAi.fromJson(b as Map<String, dynamic>),
      ],
      billsNote: j['billsNote'] as String? ?? '',
      monthEnd: (j['monthEnd'] as num?)?.toDouble(),
      monthEndNote: j['monthEndNote'] as String? ?? '',
      hasBudget: j['hasBudget'] as bool? ?? false,
      budgetRunout: d('budgetRunout'),
      budgetNote: j['budgetNote'] as String? ?? '',
      payday: d('payday'),
      paydaySpend: (j['paydaySpend'] as num?)?.toDouble(),
      paydayNote: j['paydayNote'] as String? ?? '',
      bikeServiceDate: d('bikeServiceDate'),
      bikeNote: j['bikeNote'] as String? ?? '',
      oilChangeDate: d('oilChangeDate'),
      oilNote: j['oilNote'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'refinedAt': {
      for (final e in refinedAt.entries) e.key.name: e.value.toIso8601String(),
    },
    'bills': [for (final b in bills) b.toJson()],
    'billsNote': billsNote,
    'monthEnd': monthEnd,
    'monthEndNote': monthEndNote,
    'hasBudget': hasBudget,
    'budgetRunout': budgetRunout?.toIso8601String(),
    'budgetNote': budgetNote,
    'payday': payday?.toIso8601String(),
    'paydaySpend': paydaySpend,
    'paydayNote': paydayNote,
    'bikeServiceDate': bikeServiceDate?.toIso8601String(),
    'bikeNote': bikeNote,
    'oilChangeDate': oilChangeDate?.toIso8601String(),
    'oilNote': oilNote,
  };

  /// When each section was last refined.
  final Map<OutlookSection, DateTime> refinedAt;
  final List<BillAi> bills;
  final String billsNote;
  final double? monthEnd;
  final String monthEndNote;

  /// True when the model answered the budget question; [budgetRunout] null
  /// then means it expects the budget to last the month.
  final bool hasBudget;
  final DateTime? budgetRunout;
  final String budgetNote;
  final DateTime? payday;
  final double? paydaySpend;
  final String paydayNote;
  final DateTime? bikeServiceDate;
  final String bikeNote;
  final DateTime? oilChangeDate;
  final String oilNote;

  /// The model's version of [label], matched ignoring case.
  BillAi? billFor(String label) {
    final key = label.trim().toLowerCase();
    for (final b in bills) {
      if (b.label.trim().toLowerCase() == key) return b;
    }
    return null;
  }

  /// Spending moves daily, so a refinement goes out of date.
  bool isOld(OutlookSection section, DateTime now) {
    final at = refinedAt[section];
    return at != null && now.difference(at).inDays >= 2;
  }

  bool get isEmpty => refinedAt.isEmpty;

  /// This estimate with the sections [fresh] refined swapped in. Everything
  /// else, refined earlier, is kept.
  OutlookAiEstimate mergedWith(OutlookAiEstimate fresh) {
    bool has(OutlookSection s) => fresh.refinedAt.containsKey(s);
    return OutlookAiEstimate(
      refinedAt: {...refinedAt, ...fresh.refinedAt},
      bills: has(OutlookSection.bills) ? fresh.bills : bills,
      billsNote: has(OutlookSection.bills) ? fresh.billsNote : billsNote,
      monthEnd: has(OutlookSection.monthEnd) ? fresh.monthEnd : monthEnd,
      monthEndNote: has(OutlookSection.monthEnd)
          ? fresh.monthEndNote
          : monthEndNote,
      hasBudget: has(OutlookSection.budget) ? fresh.hasBudget : hasBudget,
      budgetRunout: has(OutlookSection.budget)
          ? fresh.budgetRunout
          : budgetRunout,
      budgetNote: has(OutlookSection.budget) ? fresh.budgetNote : budgetNote,
      payday: has(OutlookSection.payday) ? fresh.payday : payday,
      paydaySpend: has(OutlookSection.payday) ? fresh.paydaySpend : paydaySpend,
      paydayNote: has(OutlookSection.payday) ? fresh.paydayNote : paydayNote,
      bikeServiceDate: has(OutlookSection.bike)
          ? fresh.bikeServiceDate
          : bikeServiceDate,
      bikeNote: has(OutlookSection.bike) ? fresh.bikeNote : bikeNote,
      oilChangeDate: has(OutlookSection.oil)
          ? fresh.oilChangeDate
          : oilChangeDate,
      oilNote: has(OutlookSection.oil) ? fresh.oilNote : oilNote,
    );
  }
}

const outlookAiSystemInstruction =
    'You forecast personal finance and vehicle upkeep. You are given the raw '
    'ledger rows (daily spending, income entries, each bill\'s past payments, '
    'service entries), daily riding distance and upcoming calendar events. '
    'Do the calculation yourself from those rows: total and average the '
    'spending, find each bill\'s real payment gap and amount, project the '
    'month and the budget, find the pay cycle in the income entries, and '
    'work out service timing from the entries and riding. The app\'s '
    'baselines are only a cross-check; depart from them whenever the rows '
    'support a better answer, including for holidays, trips, or a bill that '
    'is late or changing. For bike service and oil changes, work out the '
    'rider\'s vehicle from the details given and use that vehicle\'s usual '
    'service or oil change interval. Reply with one JSON object and nothing '
    'else.';

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

  final needMonth =
      asked(OutlookSection.monthEnd) || asked(OutlookSection.budget);
  if (monthPace != null && needMonth) {
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
    if (asked(OutlookSection.monthEnd)) {
      schema.add(
        '"month_end":{"amount":<number>,"reasoning":"<one sentence>"}',
      );
    }
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

/// Reads the reply, keeping every section that checks out. Null when nothing
/// usable came back.
OutlookAiEstimate? parseOutlookAiResponse(
  String raw, {
  required DateTime now,
  required List<UpcomingCharge> bills,
  Set<OutlookSection> sections = const {...OutlookSection.values},
}) {
  final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
  if (match == null) return null;
  final Object? decoded;
  try {
    decoded = jsonDecode(match.group(0)!);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final Map root = decoded;

  final today = DateTime(now.year, now.month, now.day);
  final earliest = today.subtract(const Duration(days: 14));
  final latest = today.add(const Duration(days: 400));
  bool inRange(DateTime? d) =>
      d != null && !d.isBefore(earliest) && !d.isAfter(latest);
  // Asked for one topic, models sometimes skip the wrapper key and answer
  // with the bare object.
  const topicFields = {
    'amount',
    'date',
    'runout_date',
    'items',
    'spend_until',
    'expected_date',
  };
  Map? section(String key, OutlookSection topic) {
    final value = root[key];
    if (value is Map) return value;
    if (sections.length == 1 &&
        sections.contains(topic) &&
        root.keys.any(topicFields.contains)) {
      return root;
    }
    return null;
  }

  final known = {for (final b in bills) _labelKey(b.label): b.label};
  String? knownLabel(String raw) {
    final key = _labelKey(raw);
    if (key.isEmpty) return null;
    if (known.containsKey(key)) return known[key];
    // "Internet bill" for "Internet", or the reverse.
    for (final e in known.entries) {
      if (e.key.contains(key) || key.contains(e.key)) return e.value;
    }
    return null;
  }

  final billItems = <BillAi>[];
  final billsSection = section('bills', OutlookSection.bills);
  final rawBills = root['bills'];
  final items = rawBills is List ? rawBills : billsSection?['items'];
  if (items is List) {
    for (final item in items) {
      if (item is! Map) continue;
      final rawLabel = item['label'];
      // A single known bill needs no label to be matched.
      final label = rawLabel is String
          ? knownLabel(rawLabel)
          : (bills.length == 1 ? bills.single.label : null);
      final date = _date(item['expected_date'] ?? item['date']);
      final amount = _positive(item['amount']);
      if (label == null || !inRange(date) || amount == null) continue;
      billItems.add(BillAi(label: label, expectedDate: date!, amount: amount));
    }
  }

  final monthEnd = section('month_end', OutlookSection.monthEnd);
  final budget = section('budget', OutlookSection.budget);
  final payday = section('payday', OutlookSection.payday);
  final bike = section('bike_service', OutlookSection.bike);
  final oil = section('oil_change', OutlookSection.oil);

  final paydayDate = _date(payday?['date'] ?? payday?['payday']);
  final bikeDate = _date(bike?['date']);
  final oilDate = _date(oil?['date']);
  final budgetDate = _date(budget?['runout_date']);
  // Any budget answer counts: a usable date means it runs out then, and no
  // date ("null", "lasts the month", or omitted) means it lasts the month. An
  // out-of-range date is a bad answer.
  final budgetAnswered =
      budget != null && (budgetDate == null || inRange(budgetDate));

  final monthEndAmount = _positive(monthEnd?['amount']);
  final paydaySpend = _positive(payday?['spend_until']);
  final paydayOk = inRange(paydayDate) ? paydayDate : null;
  // Maintenance can be overdue, and models then give the day it fell due,
  // which may be months back. That means "now", not a bad answer.
  DateTime? maintenanceDate(DateTime? d) {
    if (d == null || d.isAfter(latest)) return null;
    if (!d.isBefore(today)) return d;
    return today.difference(d).inDays <= 365 ? today : null;
  }

  final bikeOk = maintenanceDate(bikeDate);
  final oilOk = maintenanceDate(oilDate);

  // A section counts as refined only if it was asked for and came back usable.
  final refined = <OutlookSection, DateTime>{
    if (sections.contains(OutlookSection.bills) && billItems.isNotEmpty)
      OutlookSection.bills: now,
    if (sections.contains(OutlookSection.monthEnd) && monthEndAmount != null)
      OutlookSection.monthEnd: now,
    if (sections.contains(OutlookSection.budget) && budgetAnswered)
      OutlookSection.budget: now,
    if (sections.contains(OutlookSection.payday) &&
        (paydayOk != null || paydaySpend != null))
      OutlookSection.payday: now,
    if (sections.contains(OutlookSection.bike) && bikeOk != null)
      OutlookSection.bike: now,
    if (sections.contains(OutlookSection.oil) && oilOk != null)
      OutlookSection.oil: now,
  };

  final estimate = OutlookAiEstimate(
    refinedAt: refined,
    bills: billItems,
    billsNote: _note(billsSection?['reasoning']),
    monthEnd: monthEndAmount,
    monthEndNote: _note(monthEnd?['reasoning']),
    hasBudget: budgetAnswered,
    budgetRunout: budgetAnswered && inRange(budgetDate) ? budgetDate : null,
    budgetNote: _note(budget?['reasoning']),
    payday: paydayOk,
    paydaySpend: paydaySpend,
    paydayNote: _note(payday?['reasoning']),
    bikeServiceDate: bikeOk,
    bikeNote: _note(bike?['reasoning']),
    oilChangeDate: oilOk,
    oilNote: _note(oil?['reasoning']),
  );
  return estimate.isEmpty ? null : estimate;
}

/// Asks the configured provider to refine the non-fuel predictions. Throws
/// when the reply can't be used, so the caller can keep what it has.
Future<OutlookAiEstimate> estimateOutlookWithAi({
  required AiSettings settings,
  required Iterable<CalendarEvent> events,
  required List<UpcomingCharge> bills,
  required String currency,
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
  DateTime? now,
  AiClient client = const AiClient(maxAttempts: 2),
}) async {
  final clock = now ?? DateTime.now();
  final reply = await client.generate(
    settings: settings,
    systemInstruction: outlookAiSystemInstruction,
    prompt: buildOutlookAiPrompt(
      now: clock,
      currency: currency,
      events: events,
      bills: bills,
      monthPace: monthPace,
      budget: budget,
      payday: payday,
      bike: bike,
      oil: oil,
      rideContext: rideContext,
      history: history,
      transactions: transactions,
      spending: spending,
      activities: activities,
      sections: sections,
    ),
  );
  final estimate = parseOutlookAiResponse(
    reply,
    now: clock,
    bills: bills,
    sections: sections,
  );
  if (estimate == null) {
    final seen = reply.replaceAll(RegExp(r'\s+'), ' ').trim();
    throw FormatException(
      'The AI reply was not a usable estimate. It said: '
      '"${seen.length > 160 ? '${seen.substring(0, 160)}…' : seen}"',
    );
  }
  return estimate;
}
