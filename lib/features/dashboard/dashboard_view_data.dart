import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_prompt_builder.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/expenses/expense_prompt_builder.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/progress_review/progress_review_evaluation.dart';
import 'package:personal/features/results/analysis_snapshot_builder.dart';
import 'package:personal/features/results/derived_metric_validation.dart';
import 'package:personal/features/results/goal_tracking_builder.dart';
import 'package:personal/features/results/stable_month_detection.dart';
import 'package:personal/core/formatting.dart';

part 'dashboard_view_models.dart';
part 'dashboard_domain_status.dart';

DashboardViewData buildDashboardViewData({
  required AnalysisPeriod period,
  required MonthlyHealthSummary? healthSummary,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  required PromptConfig config,
  required AnalysisSnapshotContext snapshotContext,
}) {
  final selection = AnalysisSourceSelection.all();
  final workStats = selection.includes(AnalysisDataSourceId.location)
      ? WorkArrivalStats.analyze(
          placeVisits: location.placeVisitsInRange(
            period.dataMonthStart,
            period.dataMonthEnd,
          ),
          workAddress: config.workAddress,
          workHours: config.workHours,
        )
      : null;
  final calendarEvents = listMajorCalendarEvents(calendar);
  final expenseEvents = listExpenseAssociationCalendarEvents(calendar);
  final resolvedBudget = resolveMonthlyBudgetBdt(
    monthlyBudgetBdt: snapshotContext.monthlyBudgetBdt,
    financialInstruction: snapshotContext.financialInstruction,
  );
  final monthlyIncome = _resolvedMonthlyIncome(
    expenses: expenses,
    monthlyIncomeBdt: snapshotContext.monthlyIncomeBdt,
  );
  final fuel = mobilityFuelSummaryFromExpenses(expenses);
  final goalInput = GoalTrackingInput(
    currentLocation: location.hasAnyData ? location : null,
    previousLocation: snapshotContext.previousLocation,
    currentGameActivity: gameActivity.sessions.isNotEmpty ? gameActivity : null,
    previousGameActivity: snapshotContext.previousGameActivity,
  );
  final rideGoal = _rideGoalMetrics(goalInput);
  final gamingTrend = _gamingTrendMetrics(
    current: gameActivity,
    previous: snapshotContext.previousGameActivity,
  );

  final stableMonth = healthSummary != null && expenses.transactions.isNotEmpty
      ? _stableMonthSection(
          evaluateStableMonth(
            selection: selection,
            dailySleep: healthSummary.dailySleep,
            expenses: expenses,
            calendarEvents: calendarEvents,
            workStats: workStats,
          ),
        )
      : null;

  return DashboardViewData(
    period: period,
    periodLabel: period.dataRangeLabel,
    domains: [
      _healthStatus(healthSummary),
      _expensesStatus(expenses, resolvedBudget, monthlyIncome),
      _locationStatus(location, workStats),
      _gamingStatus(gameActivity, gamingTrend),
      _calendarStatus(calendar, calendarEvents),
    ],
    stableMonth: stableMonth,
    health: healthSummary == null
        ? null
        : _healthAnalysis(healthSummary, snapshotContext.previousHealth),
    financial: expenses.transactions.isEmpty
        ? null
        : _financialAnalysis(
            expenses: expenses,
            monthlyBudget: resolvedBudget,
            monthlyIncome: monthlyIncome,
            previousExpenses: snapshotContext.previousExpenses,
          ),
    mobility:
        location.activities.isEmpty &&
            !(workStats?.hasWorkVisits ?? false) &&
            fuel == null
        ? null
        : _mobilityAnalysis(
            location: location,
            workStats: workStats,
            fuel: fuel,
            rideGoal: rideGoal,
          ),
    gaming: gameActivity.sessions.isEmpty
        ? null
        : _gamingAnalysis(gameActivity, gamingTrend),
    calendar: calendar.events.isEmpty
        ? null
        : _calendarAnalysis(calendar, calendarEvents, expenseEvents),
  );
}

DashboardStableMonthSection _stableMonthSection(
  StableMonthAssessment assessment,
) {
  return DashboardStableMonthSection(
    canEvaluate: assessment.canEvaluate,
    isStable: assessment.isStable,
    shortSleepNights: assessment.shortSleepNights,
    sleepDebtHours: assessment.sleepDebt.inMinutes / 60,
    largestCategoryName: assessment.largestCategoryName,
    largestCategoryIncomeShare:
        assessment.largestCategorySpendingShare != null &&
            assessment.largestCategorySpendingShare! > 0
        ? assessment.largestCategorySpendingShare! * 100
        : null,
    hasSevereAnomalyCluster: assessment.hasSevereAnomalyCluster,
    severeClusterLabel: assessment.severeClusterLabel,
  );
}

DashboardHealthAnalysis _healthAnalysis(
  MonthlyHealthSummary summary,
  MonthlyHealthSummary? previous,
) {
  final nightsWithData = summary.dailySleep
      .where((night) => night.hasData)
      .toList();
  final debt = computeSleepDebt(nightsWithData);
  final consistency = computeSleepConsistency(summary.dailySleep);
  final recovery = computeSleepRecovery(summary.dailySleep);
  final clusters = detectSleepClusters(summary.dailySleep)
      .map(
        (cluster) => DashboardBarItem(
          label: cluster.label,
          value: cluster.shortCount.toDouble(),
          displayValue: '${cluster.shortCount} short nights',
        ),
      )
      .toList();

  final dailySleep = summary.dailySleep.map((entry) {
    final hours = entry.hasData
        ? entry.session!.duration.inMinutes / 60.0
        : 0.0;
    return DashboardBarItem(
      label: DateFormat('d').format(entry.wakeDate),
      value: hours,
      displayValue: entry.hasData
          ? formatDuration(entry.session!.duration)
          : '—',
    );
  }).toList();

  final previousNights = previous?.dailySleep
      .where((night) => night.hasData)
      .toList();
  final previousDebt = previousNights == null || previousNights.isEmpty
      ? null
      : computeSleepDebt(previousNights);

  return DashboardHealthAnalysis(
    sleepDebtChangeHours: previousDebt == null
        ? null
        : (debt.estimatedDebt - previousDebt.estimatedDebt).inMinutes / 60,
    nightsTracked: summary.sleepNightsTracked,
    nightsBelowTarget: debt.nightsBelowTarget,
    sleepDebtHours: debt.estimatedDebt.inMinutes / 60,
    bedtimeStdDevMinutes: consistency?.bedtimeStdDevMinutes,
    wakeStdDevMinutes: consistency?.wakeStdDevMinutes,
    recoveryRatePercent: recovery.recoveryRatePercent,
    clusters: clusters,
    dailySleep: dailySleep,
  );
}

DashboardFinancialAnalysis _financialAnalysis({
  required ExpensesSummary expenses,
  required double? monthlyBudget,
  required double monthlyIncome,
  required ExpensesSummary? previousExpenses,
}) {
  final totalSpent = expenses.totalRealExpenses;
  final previousSpent = previousExpenses?.totalRealExpenses ?? 0;
  final categories = expenses.expensesByCategory;
  final top = categories.isEmpty ? null : categories.first;
  final top3Total = categories
      .take(3)
      .fold<double>(0, (sum, category) => sum + category.total);

  return DashboardFinancialAnalysis(
    spentChangePercent: previousSpent > 0
        ? (totalSpent - previousSpent) / previousSpent * 100
        : null,
    currency: expenses.currency,
    totalSpent: totalSpent,
    totalIncome: expenses.totalIncome,
    netSurplus: expenses.netSurplus,
    monthlyBudget: monthlyBudget,
    budgetConsumedPercent: monthlyBudget != null && monthlyBudget > 0
        ? DerivedMetricValidation.sanitizePercent(
            totalSpent / monthlyBudget * 100,
          )
        : null,
    incomeUtilizationPercent: monthlyIncome > 0
        ? DerivedMetricValidation.sanitizePercent(
            totalSpent / monthlyIncome * 100,
          )
        : null,
    burnRatePercent: expenses.burnRate != null
        ? DerivedMetricValidation.sanitizePercent(expenses.burnRate! * 100)
        : null,
    topCategoryName: top?.category,
    topCategorySharePercent: top != null && totalSpent > 0
        ? DerivedMetricValidation.sanitizePercent(top.total / totalSpent * 100)
        : null,
    top3CategorySharePercent: totalSpent > 0
        ? DerivedMetricValidation.sanitizePercent(top3Total / totalSpent * 100)
        : null,
    categoryConcentration: categories
        .take(6)
        .map(
          (stat) => DashboardBarItem(
            label: stat.category,
            value: stat.total,
            displayValue: _formatMoney(stat.total, expenses.currency),
          ),
        )
        .toList(),
  );
}

DashboardMobilityAnalysis _mobilityAnalysis({
  required LocationSummary location,
  required WorkArrivalStats? workStats,
  required MobilityFuelSummary? fuel,
  required ({double? distanceKm, double? changeKm}) rideGoal,
}) {
  final motorcycleTrips = location.periodMotorcyclingActivities
      .where((trip) => trip.distanceMeters > 0)
      .toList();
  final motorcycleKm = location.periodMotorcycleDistanceMeters / 1000;
  final travelTimeHours =
      motorcycleTrips
          .fold<Duration>(Duration.zero, (sum, trip) => sum + trip.duration)
          .inMinutes /
      60;

  return DashboardMobilityAnalysis(
    motorcycleKm: motorcycleKm,
    travelTimeHours: travelTimeHours,
    workDays: workStats?.totalWorkDays ?? 0,
    lateArrivals: workStats?.lateArrivalCount ?? 0,
    lateArrivalRatePercent: workStats?.lateArrivalRate,
    averageDelayMinutes: workStats?.averageDelayMinutes,
    fuelSpend: fuel?.totalSpend,
    fuelRefuelCount: fuel?.refuelCount,
    fuelLitres: fuel?.totalLitres,
    fuelRatePerLitre: fuel?.weightedRatePerLitre,
    fuelPricedRefuelCount: fuel?.pricedRefuels.length,
    fuelCurrency: fuel?.currency ?? '',
    byTransport: location.periodTransportationByType
        .take(6)
        .map(
          (mode) => DashboardBarItem(
            label: _titleCase(mode.type),
            value: mode.distanceMeters / 1000,
            displayValue:
                '${(mode.distanceMeters / 1000).toStringAsFixed(1)} km',
          ),
        )
        .toList(),
    rideDistanceKm: rideGoal.distanceKm,
    rideDistanceChangeKm: rideGoal.changeKm,
  );
}

DashboardGamingAnalysis _gamingAnalysis(
  GameActivitySummary summary,
  ({int? sessionChange, double? playTimeChangeHours}) trend,
) {
  final byGame = <String, Duration>{};
  for (final session in summary.sessions) {
    byGame[session.name] =
        (byGame[session.name] ?? Duration.zero) + session.timePlayed;
  }

  final gameBars = byGame.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return DashboardGamingAnalysis(
    sessionCount: summary.sessions.length,
    totalPlayHours: summary.totalPlayTime.inMinutes / 60,
    sessionChange: trend.sessionChange,
    playTimeChangeHours: trend.playTimeChangeHours,
    byGame: gameBars
        .take(6)
        .map(
          (entry) => DashboardBarItem(
            label: entry.key,
            value: entry.value.inMinutes / 60.0,
            displayValue: _formatPlayHours(entry.value),
          ),
        )
        .toList(),
  );
}

DashboardCalendarAnalysis _calendarAnalysis(
  CalendarSummary summary,
  List<MajorCalendarEvent> majorEvents,
  List<MajorCalendarEvent> expenseEvents,
) {
  final weekdayCounts = List<int>.filled(7, 0);
  for (final event in summary.events) {
    final weekday = event.start.toLocal().weekday - 1;
    if (weekday >= 0 && weekday < 7) weekdayCounts[weekday]++;
  }

  const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final bars = <DashboardBarItem>[];
  for (var i = 0; i < 7; i++) {
    bars.add(
      DashboardBarItem(
        label: weekdayLabels[i],
        value: weekdayCounts[i].toDouble(),
        displayValue: '${weekdayCounts[i]}',
      ),
    );
  }

  return DashboardCalendarAnalysis(
    majorEventCount: majorEvents.length,
    holidayCount: summary.events.where((event) => event.isHoliday).length,
    expenseLinkedEventCount: expenseEvents.length,
    byWeekday: bars,
  );
}

double _resolvedMonthlyIncome({
  required ExpensesSummary expenses,
  required String monthlyIncomeBdt,
}) {
  final fromProfile = parseMonthlyIncomeBdt(monthlyIncomeBdt);
  if (fromProfile != null && fromProfile > 0) return fromProfile;
  return expenses.totalIncome;
}

({double? distanceKm, double? changeKm}) _rideGoalMetrics(
  GoalTrackingInput input,
) {
  final current = input.currentLocation;
  if (current == null || !current.hasAnyData) {
    return (distanceKm: null, changeKm: null);
  }

  final currentTrips = current.periodMotorcyclingActivities
      .where((trip) => trip.distanceMeters > 0)
      .toList();
  if (currentTrips.isEmpty) return (distanceKm: null, changeKm: null);

  final currentKm =
      currentTrips.fold<double>(0, (sum, trip) => sum + trip.distanceMeters) /
      1000;

  final previous = input.previousLocation;
  if (previous == null || !previous.hasAnyData) {
    return (distanceKm: currentKm, changeKm: null);
  }

  final previousKm =
      previous.periodMotorcyclingActivities
          .where((trip) => trip.distanceMeters > 0)
          .fold<double>(0, (sum, trip) => sum + trip.distanceMeters) /
      1000;

  return (distanceKm: currentKm, changeKm: currentKm - previousKm);
}

({int? sessionChange, double? playTimeChangeHours}) _gamingTrendMetrics({
  required GameActivitySummary current,
  required GameActivitySummary? previous,
}) {
  if (previous == null || previous.sessions.isEmpty) {
    return (sessionChange: null, playTimeChangeHours: null);
  }

  final sessionChange = current.sessions.length - previous.sessions.length;
  final playTimeChangeHours =
      (current.totalPlayTime.inMinutes - previous.totalPlayTime.inMinutes) / 60;

  return (
    sessionChange: sessionChange,
    playTimeChangeHours: playTimeChangeHours,
  );
}

String _formatMoney(double amount, String currency) {
  return '${currencyPrefix(currency)}${amount.toStringAsFixed(0)}';
}

String _formatPlayHours(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  return '${minutes}m';
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  final lower = value.toLowerCase().replaceAll('_', ' ');
  return lower
      .split(' ')
      .map((word) {
        if (word.isEmpty) return word;
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}
