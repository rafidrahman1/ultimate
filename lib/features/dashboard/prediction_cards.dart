import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/life_forecast_panel.dart';
import 'package:personal/features/dashboard/predictions_provider.dart';
import 'package:personal/features/expenses/fuel_forecast_ai.dart';
import 'package:personal/features/expenses/outlook_ai.dart';
import 'package:personal/features/expenses/outlook_forecast.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_ai.dart';

/// How much attention a prediction deserves, which drives its colour and order.
enum PredictionUrgency { critical, soon, normal }

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
  });

  final String key;

  PredictionGroup get group =>
      LifeForecastKind.byName(key)?.group ??
      switch (key) {
        'fuel' ||
        'bills' ||
        'budget' ||
        'payday' ||
        'month' => PredictionGroup.money,
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
            '~${money.format(ai?.amount ?? fuel.typicalAmount)} · '
            '${fuel.refuelCount} past refuels',
        accent: expenses,
        urgency: _urgencyForDays(days),
        date: date,
        aiRefined: ai != null,
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
            '${next.label} · ${money.format(next.amount)}'
            '${more > 0 ? ' · +$more more' : ''}',
        accent: expenses,
        urgency: _urgencyForDays(days),
        date: next.expectedDate,
        aiRefined: fresh(OutlookSection.bills),
      ),
    );
  }

  final budget = p.budget;
  if (budget != null) {
    final aiRunout = fresh(OutlookSection.budget) && outlookAi!.hasBudget;
    final runout = aiRunout ? outlookAi.budgetRunout : budget.runoutDate;
    if (budget.isOver) {
      cards.add(
        PredictionCardData(
          key: 'budget',
          icon: Icons.savings_rounded,
          label: 'Budget',
          headline: 'Over budget',
          detail: 'By ${money.format(-budget.left)} so far',
          accent: palette.statusCritical,
          urgency: PredictionUrgency.critical,
          aiRefined: aiRunout,
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
              '${money.format(budget.left)} left of '
              '${money.format(budget.budget)}',
          accent: palette.statusCritical,
          urgency: PredictionUrgency.critical,
          date: runout,
          aiRefined: aiRunout,
        ),
      );
    } else {
      cards.add(
        PredictionCardData(
          key: 'budget',
          icon: Icons.savings_rounded,
          label: 'Budget',
          headline: 'On track',
          detail: '${money.format(budget.left)} left, lasts the month',
          accent: palette.statusGood,
          urgency: PredictionUrgency.normal,
          aiRefined: aiRunout,
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
            '~${money.format(payday.amount)} · '
            '${money.format(payday.billsBefore)} in bills before',
        accent: palette.statusGood,
        urgency: PredictionUrgency.normal,
        date: date,
        aiRefined: fresh(OutlookSection.payday),
      ),
    );
  }

  final pace = p.monthPace;
  if (pace != null) {
    final aiEnd = fresh(OutlookSection.monthEnd) ? outlookAi!.monthEnd : null;
    final projected = aiEnd ?? pace.projected;
    final high = pace.typicalMonth > 0 && projected > pace.typicalMonth * 1.1;
    cards.add(
      PredictionCardData(
        key: 'month',
        icon: Icons.trending_up_rounded,
        label: 'Month-end spend',
        headline: money.format(projected),
        detail: 'Usual month ${money.format(pace.typicalMonth)}',
        accent: high ? palette.warning : expenses,
        urgency: high ? PredictionUrgency.soon : PredictionUrgency.normal,
        aiRefined: aiEnd != null,
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
            ? '~${km.round()} km to go · last '
                  '${DateFormat('MMM d').format(forecast.lastDone)}'
            : 'Last done ${DateFormat('MMM d').format(forecast.lastDone)}',
        accent: overdue ? palette.warning : mobility,
        urgency: overdue
            ? PredictionUrgency.soon
            : days != null
            ? _urgencyForDays(days)
            : PredictionUrgency.normal,
        date: date,
        aiRefined: aiDate != null,
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
