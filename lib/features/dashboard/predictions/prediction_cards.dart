import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/predictions_provider.dart';
import 'package:personal/features/dashboard/ui/life_forecast_panel.dart';
import 'package:personal/features/forecasts/fuel/fuel_forecast_ai.dart';
import 'package:personal/features/forecasts/life/life_forecast.dart';
import 'package:personal/features/forecasts/life/life_forecast_ai.dart';
import 'package:personal/features/forecasts/outlook/outlook_ai.dart';
import 'package:personal/features/forecasts/outlook/outlook_forecast.dart';

/// How much attention a prediction deserves, which drives its colour and order.
enum PredictionUrgency { critical, soon, normal }

/// How far the underlying data can be trusted. Reflects data quantity and
/// completeness, not a calibrated probability.
enum PredictionConfidence {
  high('High'),
  moderate('Moderate'),
  low('Low');

  const PredictionConfidence(this.label);
  final String label;
}

/// One input the estimate used, shown under "Why this estimate?".
class PredictionFact {
  const PredictionFact(this.label, this.value);
  final String label;
  final String value;
}

PredictionConfidence _byCount(int n, {required int high, required int mid}) =>
    n >= high
    ? PredictionConfidence.high
    : n >= mid
    ? PredictionConfidence.moderate
    : PredictionConfidence.low;

/// Everything one compact prediction card shows. [key] ties it to its full
/// panel in the detail sheet.
class PredictionCardData {
  const PredictionCardData({
    required this.key,
    required this.icon,
    required this.label,
    required this.headline,
    required this.detail,
    required this.accent,
    required this.urgency,
    this.date,
    this.aiRefined = false,
    this.confidence,
    this.confidenceReason,
    this.facts = const [],
    this.assumptions = const [],
  });

  final String key;

  PredictionGroup get group =>
      LifeForecastKind.byName(key)?.group ??
      switch (key) {
        'fuel' || 'bills' || 'budget' || 'payday' => PredictionGroup.money,
        _ => PredictionGroup.life,
      };

  final IconData icon;
  final String label;
  final String headline;
  final String detail;
  final Color accent;
  final PredictionUrgency urgency;

  /// When the predicted event lands; null for figures without a date.
  final DateTime? date;
  final bool aiRefined;

  /// Null when the data gives no honest basis for rating the estimate.
  final PredictionConfidence? confidence;
  final String? confidenceReason;

  /// The real inputs behind the estimate; empty when none are available.
  final List<PredictionFact> facts;
  final List<String> assumptions;
}

String _daysLabel(int days, DateTime date) {
  if (days < 0) return '${-days} d overdue';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days > 60) return DateFormat('MMM d').format(date);
  return 'in $days d';
}

PredictionUrgency _urgencyForDays(int days) =>
    days <= 3 ? PredictionUrgency.soon : PredictionUrgency.normal;

/// Compact cards for every prediction, most urgent first.
List<PredictionCardData> buildPredictionCards(
  BuildContext context,
  Predictions p, {
  required NumberFormat money,
  required FuelAiEstimate? fuelAi,
  required OutlookAiEstimate? outlookAi,
  LifeAiEstimate? lifeAi,
  DateTime? now,
}) {
  final palette = context.palette;
  final expenses = AppSemanticColors.expenses(context);
  final mobility = AppSemanticColors.mobility(context);
  final today = DateTime.now();
  final day = DateTime(
    (now ?? today).year,
    (now ?? today).month,
    (now ?? today).day,
  );
  int daysTo(DateTime d) =>
      DateTime(d.year, d.month, d.day).difference(day).inDays;

  /// An AI section figure is used only while it is fresh.
  bool fresh(OutlookSection s) =>
      outlookAi != null &&
      outlookAi.refinedAt.containsKey(s) &&
      !outlookAi.isOld(s, day);

  final cards = <PredictionCardData>[];

  final fuel = p.fuel;
  if (fuel != null) {
    final ai = fuelAi != null && !fuelAi.isStaleFor(fuel) ? fuelAi : null;
    final date = ai?.expectedDate ?? fuel.expectedDate;
    final days = daysTo(date);
    cards.add(
      PredictionCardData(
        key: 'fuel',
        icon: Icons.local_gas_station_rounded,
        label: 'Next fuel',
        headline: _daysLabel(days, date),
        detail:
            'Expect to spend about ${money.format(ai?.amount ?? fuel.typicalAmount)} '
            'filling up, based on your last ${fuel.refuelCount} refuels.'
            '${fuel.kmSinceRefuel == null ? '' : ' Ridden ${fuel.kmSinceRefuel!.round()} km since the last refuel${fuel.distance == null ? '' : ', about ${fuel.distance!.kmLeft.round()} km left in the tank'}.'}',
        accent: expenses,
        urgency: _urgencyForDays(days),
        date: date,
        aiRefined: ai != null,
        confidence: _byCount(fuel.refuelCount, high: 6, mid: 3),
        confidenceReason:
            'Based on ${fuel.refuelCount} recorded refuels'
            '${fuel.distance == null ? '' : ' and your recent distance'}.',
        facts: [
          PredictionFact('Refuels recorded', '${fuel.refuelCount}'),
          PredictionFact(
            'Last refuel',
            DateFormat('MMM d').format(fuel.lastRefuel),
          ),
          PredictionFact(
            'Typical gap',
            '${fuel.typicalIntervalDays.round()} days',
          ),
          PredictionFact('Typical fill', money.format(fuel.typicalAmount)),
          if (fuel.kmSinceRefuel != null)
            PredictionFact(
              'Ridden since refuel',
              '${fuel.kmSinceRefuel!.round()} km',
            ),
          if (fuel.distance != null)
            PredictionFact(
              'Estimated range left',
              '${fuel.distance!.kmLeft.round()} km',
            ),
        ],
        assumptions: [
          if (fuel.distance != null)
            'Recent riding pattern (${fuel.distance!.dailyKm.round()} km/day) continues.'
          else
            'You refuel at roughly your usual interval.',
        ],
      ),
    );
  }

  if (p.upcomingCharges.isNotEmpty) {
    final sorted = [...p.upcomingCharges]
      ..sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    final next = sorted.first;
    final days = daysTo(next.expectedDate);
    final more = sorted.length - 1;
    cards.add(
      PredictionCardData(
        key: 'bills',
        icon: Icons.receipt_long_rounded,
        label: sorted.length == 1 ? 'Next bill' : 'Upcoming bills',
        headline: _daysLabel(days, next.expectedDate),
        detail:
            '${next.label}, about ${money.format(next.amount)}'
            '${more > 0 ? ', plus $more more bill${more == 1 ? '' : 's'} coming up' : ''}.',
        accent: expenses,
        urgency: _urgencyForDays(days),
        date: next.expectedDate,
        aiRefined: fresh(OutlookSection.bills),
      ),
    );
  }

  final budget = p.budget;
  if (budget != null) {
    final budgetFacts = [
      PredictionFact('Monthly budget', money.format(budget.budget)),
      PredictionFact('Spent so far', money.format(budget.spent)),
      PredictionFact('Left', money.format(budget.left)),
      PredictionFact('Projected month total', money.format(budget.projected)),
    ];
    const budgetAssumptions = [
      'Spending continues at your typical pace for the rest of the month.',
    ];
    final aiRunout = fresh(OutlookSection.budget) && outlookAi!.hasBudget;
    final runout = aiRunout ? outlookAi.budgetRunout : budget.runoutDate;
    if (budget.isOver) {
      cards.add(
        PredictionCardData(
          key: 'budget',
          icon: Icons.savings_rounded,
          label: 'Budget',
          headline: 'Over budget',
          detail:
              "You've gone ${money.format(-budget.left)} past this month's budget.",
          accent: palette.statusCritical,
          urgency: PredictionUrgency.critical,
          aiRefined: aiRunout,
          facts: budgetFacts,
          assumptions: budgetAssumptions,
        ),
      );
    } else if (runout != null) {
      cards.add(
        PredictionCardData(
          key: 'budget',
          icon: Icons.savings_rounded,
          label: 'Budget runs out',
          headline: _daysLabel(daysTo(runout), runout),
          detail:
              'Only ${money.format(budget.left)} left of your '
              '${money.format(budget.budget)} budget at this pace.',
          accent: palette.statusCritical,
          urgency: PredictionUrgency.critical,
          date: runout,
          aiRefined: aiRunout,
          facts: budgetFacts,
          assumptions: budgetAssumptions,
        ),
      );
    } else {
      cards.add(
        PredictionCardData(
          key: 'budget',
          icon: Icons.savings_rounded,
          label: 'Budget',
          headline: 'On track',
          detail:
              '${money.format(budget.left)} left, enough to last the rest of the month.',
          accent: palette.statusGood,
          urgency: PredictionUrgency.normal,
          aiRefined: aiRunout,
          facts: budgetFacts,
          assumptions: budgetAssumptions,
        ),
      );
    }
  }

  final payday = p.payday;
  if (payday != null) {
    final date = fresh(OutlookSection.payday) && outlookAi!.payday != null
        ? outlookAi.payday!
        : payday.expectedDate;
    cards.add(
      PredictionCardData(
        key: 'payday',
        icon: Icons.payments_rounded,
        label: payday.label,
        headline: _daysLabel(daysTo(date), date),
        detail:
            'Expect about ${money.format(payday.amount)}. '
            '${payday.billsBefore > 0 ? '${money.format(payday.billsBefore)} in bills fall due before then.' : 'No bills are due before then.'}',
        accent: palette.statusGood,
        urgency: PredictionUrgency.normal,
        date: date,
        aiRefined: fresh(OutlookSection.payday),
        facts: [
          PredictionFact('Expected pay', money.format(payday.amount)),
          PredictionFact(
            'Expected date',
            DateFormat('MMM d').format(payday.expectedDate),
          ),
          PredictionFact('Bills due before', money.format(payday.billsBefore)),
          PredictionFact(
            'Expected spending until then',
            money.format(payday.expectedSpend),
          ),
        ],
        assumptions: const ['Pay arrives on its usual day and amount.'],
      ),
    );
  }

  for (final entry in [
    (p.bikeService, 'bike', OutlookSection.bike),
    (p.bikeOil, 'oil', OutlookSection.oil),
  ]) {
    final forecast = entry.$1;
    if (forecast == null) continue;
    final aiDate = fresh(entry.$3)
        ? (entry.$3 == OutlookSection.bike
              ? outlookAi!.bikeServiceDate
              : outlookAi!.oilChangeDate)
        : null;
    final date = aiDate ?? forecast.expectedDate;
    final days = date == null ? null : daysTo(date);
    final overdue = forecast.isOverdue || (days != null && days < 0);
    final km = forecast.kmLeft;
    cards.add(
      PredictionCardData(
        key: entry.$2,
        icon: entry.$2 == 'oil'
            ? Icons.oil_barrel_rounded
            : Icons.build_rounded,
        label: forecast.kind == BikeMaintenance.oil
            ? 'Oil change'
            : 'Bike service',
        headline: overdue
            ? 'Overdue'
            : date != null
            ? _daysLabel(days!, date)
            : km != null
            ? '~${km.round()} km left'
            : 'Not enough data',
        detail: km != null && !overdue
            ? 'About ${km.round()} km until the next ${forecast.noun}. '
                  'Last done ${DateFormat('MMM d').format(forecast.lastDone)}.'
            : overdue
            ? 'Past the usual interval since ${DateFormat('MMM d').format(forecast.lastDone)}.'
            : 'Last done ${DateFormat('MMM d').format(forecast.lastDone)}.',
        accent: overdue ? palette.warning : mobility,
        urgency: overdue
            ? PredictionUrgency.soon
            : days != null
            ? _urgencyForDays(days)
            : PredictionUrgency.normal,
        date: date,
        aiRefined: aiDate != null,
        confidence: forecast.partialData
            ? PredictionConfidence.low
            : _byCount(forecast.count, high: 4, mid: 2),
        confidenceReason: forecast.partialData
            ? 'Some inputs are missing.'
            : 'Based on ${forecast.count} past '
                  '${forecast.count == 1 ? 'entry' : 'entries'}.',
        facts: [
          PredictionFact(
            'Last done',
            DateFormat('MMM d').format(forecast.lastDone),
          ),
          PredictionFact('Past entries', '${forecast.count}'),
          PredictionFact('Ridden since', '${forecast.kmSince.round()} km'),
          if (forecast.intervalKm != null)
            PredictionFact(
              'Typical interval',
              '${forecast.intervalKm!.round()} km',
            ),
          if (forecast.intervalDays != null)
            PredictionFact('Typical gap', '${forecast.intervalDays} days'),
        ],
      ),
    );
  }

  final odo = p.odometer;
  if (odo != null) {
    final latest = odo.latest;
    final missing = !odo.loggedInMonthOf(day);
    final rate = odo.perMonth;
    cards.add(
      PredictionCardData(
        key: 'odometer',
        icon: Icons.speed_rounded,
        label: 'Bike odometer',
        headline: latest == null
            ? 'Log it'
            : '${NumberFormat.decimalPattern().format(latest.km.round())} km',
        detail: latest == null
            ? 'Add your first odometer reading'
            : missing
            ? "You haven't logged this month's reading yet. Tap to add it."
            : rate == null
            ? 'Log another reading next month to see how far you ride.'
            : 'You ride about ${rate.round()} km a month. Last reading '
                  '${DateFormat('MMM d').format(latest.date)}.',
        accent: missing ? palette.warning : mobility,
        urgency: missing && latest != null
            ? PredictionUrgency.soon
            : PredictionUrgency.normal,
      ),
    );
  }

  for (final f in p.life) {
    final ai = lifeAi?.freshFor(f, today);
    final date = ai?.date ?? f.date;
    cards.add(
      PredictionCardData(
        key: f.key,
        icon: lifeForecastIcon(f.kind),
        label: f.label,
        headline: ai?.headline ?? f.headline,
        detail: ai != null && ai.detail.isNotEmpty ? ai.detail : f.detail,
        accent: f.attention
            ? palette.warning
            : lifeForecastColor(context, f.kind),
        urgency: f.attention
            ? PredictionUrgency.soon
            : PredictionUrgency.normal,
        date: date,
        aiRefined: ai != null,
      ),
    );
  }

  // Urgent first, then soonest; undated figures trail their urgency group.
  cards.sort((a, b) {
    final byUrgency = a.urgency.index.compareTo(b.urgency.index);
    if (byUrgency != 0) return byUrgency;
    if (a.date == null || b.date == null) {
      return a.date == null && b.date == null ? 0 : (a.date == null ? 1 : -1);
    }
    return a.date!.compareTo(b.date!);
  });
  return cards;
}
