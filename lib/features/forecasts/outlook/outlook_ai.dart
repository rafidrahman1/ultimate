import 'dart:convert';

import 'package:intl/intl.dart';

import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/expenses/analysis/ai_ledger_text.dart';
import 'package:personal/features/expenses/analysis/expense_insights.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/forecasts/outlook/outlook_forecast.dart';
import 'package:personal/features/forecasts/outlook/recurring_forecast.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/results/ai/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

part 'outlook_ai_prompt.dart';
part 'outlook_ai_parser.dart';
part 'outlook_ai_runner.dart';

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
enum OutlookSection { bills, budget, payday, bike, oil }

/// The model's reading of the non-fuel predictions. Each section is refined
/// separately, so a section never refined, or one the model got wrong, is
/// simply absent from [refinedAt].
class OutlookAiEstimate {
  const OutlookAiEstimate({
    this.refinedAt = const {},
    this.bills = const [],
    this.billsNote = '',
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
