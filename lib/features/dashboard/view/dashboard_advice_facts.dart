import 'package:personal/features/dashboard/view/dashboard_view_data.dart';

String _n(num v, [int d = 1]) => v.toStringAsFixed(d);

String _signed(double v, [int d = 1]) => '${v >= 0 ? '+' : ''}${_n(v, d)}';

/// Compact, number-only summary of everything on the dashboard this period,
/// for the AI advice prompt. Sources with no data are left out entirely, so
/// the model only sees what can actually be analysed.
String buildAdviceFacts(DashboardViewData d) {
  final out = StringBuffer()..writeln('Period: ${d.periodLabel}');

  final h = d.health;
  if (h != null) {
    out
      ..writeln('\n[Sleep]')
      ..writeln(
        'nights tracked ${h.nightsTracked}, below target ${h.nightsBelowTarget}, '
        'sleep debt ${_n(h.sleepDebtHours)}h'
        '${h.sleepDebtChangeHours == null ? '' : ' (${_signed(h.sleepDebtChangeHours!)}h vs last period)'}',
      );
    if (h.bedtimeStdDevMinutes != null || h.wakeStdDevMinutes != null) {
      out.writeln(
        'bedtime varies ±${_n(h.bedtimeStdDevMinutes ?? 0, 0)} min, '
        'wake time ±${_n(h.wakeStdDevMinutes ?? 0, 0)} min',
      );
    }
    if (h.recoveryRatePercent != null) {
      out.writeln(
        'recovery after short nights ${_n(h.recoveryRatePercent!, 0)}%',
      );
    }
    for (final c in h.clusters) {
      out.writeln('short-night cluster: ${c.label} (${c.displayValue})');
    }
  }

  final f = d.financial;
  if (f != null) {
    out
      ..writeln('\n[Spending] currency ${f.currency}')
      ..writeln(
        'spent ${_n(f.totalSpent, 0)}, income ${_n(f.totalIncome, 0)}, '
        'net ${_n(f.netSurplus, 0)}'
        '${f.spentChangePercent == null ? '' : ', spend ${_signed(f.spentChangePercent!, 0)}% vs last month'}',
      );
    if (f.monthlyBudget != null) {
      out.writeln(
        'budget ${_n(f.monthlyBudget!, 0)}, used '
        '${_n(f.budgetConsumedPercent ?? 0, 0)}%',
      );
    }
    if (f.topCategoryName != null) {
      out.writeln(
        'top category ${f.topCategoryName} '
        '${_n(f.topCategorySharePercent ?? 0, 0)}% of spend, top 3 '
        '${_n(f.top3CategorySharePercent ?? 0, 0)}%',
      );
    }
    out.writeln(
      'categories: ${f.categoryConcentration.map((c) => '${c.label} ${c.displayValue}').join(', ')}',
    );
  }

  final m = d.mobility;
  if (m != null) {
    out.writeln('\n[Mobility & work]');
    out.writeln(
      'motorcycle ${_n(m.motorcycleKm, 0)} km, ${_n(m.travelTimeHours)}h riding',
    );
    if (m.workDays > 0) {
      out.writeln(
        'work days ${m.workDays}, late ${m.lateArrivals}'
        '${m.lateArrivalRatePercent == null ? '' : ' (${_n(m.lateArrivalRatePercent!, 0)}%)'}'
        '${m.averageDelayMinutes == null ? '' : ', avg delay ${_n(m.averageDelayMinutes!, 0)} min'}',
      );
    }
    if (m.fuelSpend != null) {
      out.writeln(
        'fuel ${_n(m.fuelSpend!, 0)} over ${m.fuelRefuelCount ?? 0} refuels',
      );
    }
    if (m.rideDistanceChangeKm != null) {
      out.writeln('riding ${_signed(m.rideDistanceChangeKm!, 0)} km vs last');
    }
  }

  final g = d.gaming;
  if (g != null) {
    out
      ..writeln('\n[Gaming]')
      ..writeln(
        '${g.sessionCount} sessions, ${_n(g.totalPlayHours)}h'
        '${g.playTimeChangeHours == null ? '' : ' (${_signed(g.playTimeChangeHours!)}h vs last period)'}'
        '; top: ${g.byGame.take(3).map((e) => '${e.label} ${e.displayValue}').join(', ')}',
      );
  }

  final s = d.screenTime;
  if (s != null) {
    out
      ..writeln('\n[Screen time]')
      ..writeln(
        'avg ${_n(s.avgHoursPerDay)}h/day over ${s.daysTracked} days'
        '${s.avgChangeHours == null ? '' : ' (${_signed(s.avgChangeHours!)}h vs last)'}'
        '${s.heaviestDayLabel == null ? '' : ', heaviest ${s.heaviestDayLabel} ${_n(s.heaviestDayHours ?? 0)}h'}'
        '; top apps: ${s.topApps.take(3).map((e) => '${e.label} ${e.displayValue}').join(', ')}',
      );
  }

  final c = d.calendar;
  if (c != null) {
    out
      ..writeln('\n[Calendar]')
      ..writeln(
        '${c.majorEventCount} major events, ${c.holidayCount} holidays, '
        '${c.expenseLinkedEventCount} linked to spending',
      );
  }

  if (d.crossInsights.isNotEmpty) {
    out.writeln('\n[Links between sources] (days = overlapping days used)');
    for (final e in d.crossInsights) {
      out.writeln(
        '- ${e.title}: ${e.detail} [${e.days} days'
        '${e.notable ? '' : ', no clear link'}]',
      );
    }
  }
  if (d.adviceDetail.isNotEmpty) out.writeln('\n${d.adviceDetail}');
  return out.toString().trimRight();
}
