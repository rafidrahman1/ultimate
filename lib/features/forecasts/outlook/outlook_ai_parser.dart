part of 'outlook_ai.dart';

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
