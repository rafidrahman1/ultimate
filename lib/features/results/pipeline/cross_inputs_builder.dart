import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/forecasts/life/life_raw_data.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/analysis/work_arrival_stats.dart';
import 'package:personal/features/results/pipeline/cross_analysis.dart';
import 'package:personal/features/screen_time/data/screen_time_models.dart';

/// Lines up every source's figures by day for the selected analysis period.
CrossInputs buildCrossInputs({
  required AnalysisPeriod period,
  MonthlyHealthSummary? health,
  ExpensesSummary? expenses,
  GameActivitySummary? games,
  ScreenTimeSummary? screen,
  CalendarSummary? calendar,
  WorkArrivalStats? work,
}) {
  final start = DateTime(
    period.dataMonthStart.year,
    period.dataMonthStart.month,
    period.dataMonthStart.day,
  );
  final end = DateTime(
    period.dataMonthEnd.year,
    period.dataMonthEnd.month,
    period.dataMonthEnd.day,
  );
  final days = [
    for (
      var d = start;
      !d.isAfter(end);
      d = DateTime(d.year, d.month, d.day + 1)
    )
      d,
  ];

  Map<DateTime, double> zeroFilled(Map<DateTime, double> sparse) => {
    for (final d in days) d: sparse[d] ?? 0,
  };

  final vitalsDays = health?.vitals?.days ?? const [];
  final screenByDay = {
    for (final e in (screen?.byDay ?? const <DateTime, Duration>{}).entries)
      e.key: e.value.inMinutes / 60,
  };

  return CrossInputs(
    sleepHours: dayMap([
      for (final n in health?.dailySleep ?? const <DailySleepEntry>[])
        if (n.hasData)
          (date: n.wakeDate, value: n.session!.duration.inMinutes / 60),
    ]),
    steps: dayMap([
      for (final v in vitalsDays)
        if (v.steps != null) (date: v.date, value: v.steps!.toDouble()),
    ]),
    restingHr: dayMap([
      for (final v in vitalsDays)
        if (v.restingHr != null) (date: v.date, value: v.restingHr!.toDouble()),
    ]),
    gamingHours: games == null || games.sessions.isEmpty
        ? const {}
        : zeroFilled(
            dayMap([
              for (final s in games.sessions)
                (date: s.sessionDate, value: s.timePlayed.inMinutes / 60),
            ], sum: true),
          ),
    screenHours: screenByDay,
    spend: expenses == null || expenses.transactions.isEmpty
        ? const {}
        : zeroFilled(
            dayMap([
              for (final t in expenses.transactions)
                if (t.isRealExpense) (date: t.date, value: t.amount.abs()),
            ], sum: true),
          ),
    eventHours: calendar == null || calendar.events.isEmpty
        ? const {}
        : zeroFilled(eventHoursByDayOf(calendar.events)),
    lateDays: {
      for (final a in work?.lateArrivals ?? const <WorkDayArrival>[])
        DateTime(a.date.year, a.date.month, a.date.day),
    },
    onTimeDays: () {
      final late = {
        for (final a in work?.lateArrivals ?? const <WorkDayArrival>[])
          DateTime(a.date.year, a.date.month, a.date.day),
      };
      return {
        for (final a in work?.workDays ?? const <WorkDayArrival>[])
          if (!late.contains(DateTime(a.date.year, a.date.month, a.date.day)))
            DateTime(a.date.year, a.date.month, a.date.day),
      };
    }(),
    currency: expenses?.currency ?? '',
  );
}
