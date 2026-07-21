import 'package:intl/intl.dart';

import 'package:personal/core/analytics_pipeline_validation.dart';
import 'package:personal/core/derived_metric_validation.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_source_selection.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/calendar/calendar_event_summary.dart';
import 'package:personal/features/dashboard/stable_month_detection.dart';
import 'package:personal/features/expenses/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/health_summary.dart';
import 'package:personal/features/health/sleep_metrics.dart';
import 'package:personal/features/location/mobility_fuel_summary.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/location/work_schedule_settings_service.dart';

class DashboardBarItem {
  const DashboardBarItem({
    required this.label,
    required this.value,
    required this.displayValue,
  });

  final String label;
  final double value;
  final String displayValue;
}

class DashboardDomainStatus {
  const DashboardDomainStatus({
    required this.id,
    required this.label,
    required this.iconName,
    required this.hasData,
    required this.headline,
    required this.detail,
  });

  final String id;
  final String label;
  final String iconName;
  final bool hasData;
  final String headline;
  final String detail;
}

class DashboardStableMonthSection {
  const DashboardStableMonthSection({
    required this.canEvaluate,
    required this.isStable,
    required this.shortSleepNights,
    required this.sleepDebtHours,
    this.largestCategoryName,
    this.largestCategoryIncomeShare,
    required this.hasSevereAnomalyCluster,
    this.severeClusterLabel,
  });

  final bool canEvaluate;
  final bool isStable;
  final int shortSleepNights;
  final double sleepDebtHours;
  final String? largestCategoryName;
  final double? largestCategoryIncomeShare;
  final bool hasSevereAnomalyCluster;
  final String? severeClusterLabel;
}

class DashboardHealthAnalysis {
  const DashboardHealthAnalysis({
    required this.nightsTracked,
    required this.nightsBelowTarget,
    required this.sleepDebtHours,
    required this.bedtimeStdDevMinutes,
    required this.wakeStdDevMinutes,
    required this.recoveryRatePercent,
    required this.clusters,
    required this.dailySleep,
  });

  final int nightsTracked;
  final int nightsBelowTarget;
  final double sleepDebtHours;
  final double? bedtimeStdDevMinutes;
  final double? wakeStdDevMinutes;
  final double? recoveryRatePercent;
  final List<DashboardBarItem> clusters;
  final List<DashboardBarItem> dailySleep;
}

class DashboardFinancialAnalysis {
  const DashboardFinancialAnalysis({
    required this.currency,
    required this.totalSpent,
    required this.totalIncome,
    required this.netSurplus,
    this.monthlyBudget,
    this.budgetConsumedPercent,
    this.incomeUtilizationPercent,
    this.burnRatePercent,
    this.topCategoryName,
    this.topCategorySharePercent,
    this.top3CategorySharePercent,
    required this.categoryConcentration,
  });

  final String currency;
  final double totalSpent;
  final double totalIncome;
  final double netSurplus;
  final double? monthlyBudget;
  final double? budgetConsumedPercent;
  final double? incomeUtilizationPercent;
  final double? burnRatePercent;
  final String? topCategoryName;
  final double? topCategorySharePercent;
  final double? top3CategorySharePercent;
  final List<DashboardBarItem> categoryConcentration;
}

class DashboardMobilityAnalysis {
  const DashboardMobilityAnalysis({
    required this.motorcycleKm,
    required this.travelTimeHours,
    required this.workDays,
    required this.lateArrivals,
    this.lateArrivalRatePercent,
    this.averageDelayMinutes,
    this.fuelSpend,
    this.fuelRefuelCount,
    required this.byTransport,
    this.cyclingDistanceKm,
    this.cyclingDistanceChangeKm,
  });

  final double motorcycleKm;
  final double travelTimeHours;
  final int workDays;
  final int lateArrivals;
  final double? lateArrivalRatePercent;
  final double? averageDelayMinutes;
  final double? fuelSpend;
  final int? fuelRefuelCount;
  final List<DashboardBarItem> byTransport;
  final double? cyclingDistanceKm;
  final double? cyclingDistanceChangeKm;
}

class DashboardGamingAnalysis {
  const DashboardGamingAnalysis({
    required this.sessionCount,
    required this.totalPlayHours,
    this.sessionChange,
    this.playTimeChangeHours,
    required this.byGame,
  });

  final int sessionCount;
  final double totalPlayHours;
  final int? sessionChange;
  final double? playTimeChangeHours;
  final List<DashboardBarItem> byGame;
}

class DashboardCalendarAnalysis {
  const DashboardCalendarAnalysis({
    required this.majorEventCount,
    required this.holidayCount,
    required this.expenseLinkedEventCount,
    required this.byWeekday,
  });

  final int majorEventCount;
  final int holidayCount;
  final int expenseLinkedEventCount;
  final List<DashboardBarItem> byWeekday;
}

class DashboardViewData {
  const DashboardViewData({
    required this.period,
    required this.periodLabel,
    required this.domains,
    this.stableMonth,
    this.health,
    this.financial,
    this.mobility,
    this.gaming,
    this.calendar,
  });

  final AnalysisPeriod period;
  final String periodLabel;
  final List<DashboardDomainStatus> domains;
  final DashboardStableMonthSection? stableMonth;
  final DashboardHealthAnalysis? health;
  final DashboardFinancialAnalysis? financial;
  final DashboardMobilityAnalysis? mobility;
  final DashboardGamingAnalysis? gaming;
  final DashboardCalendarAnalysis? calendar;

  int get loadedSourceCount => domains.where((domain) => domain.hasData).length;

  int get totalSourceCount => domains.length;

  bool get hasAnyData => loadedSourceCount > 0;
}

DashboardViewData buildDashboardViewData({
  required AnalysisPeriod period,
  required MonthlyHealthSummary? healthSummary,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  WorkScheduleSettings workSchedule = const WorkScheduleSettings(),
  LocationSummary? previousLocation,
  GameActivitySummary? previousGameActivity,
}) {
  final workStats = location.hasAnyData && workSchedule.isConfigured
      ? WorkArrivalStats.analyze(
          placeVisits: location.placeVisitsInRange(
            period.dataMonthStart,
            period.dataMonthEnd,
          ),
          workAddress: workSchedule.workAddress,
          workHours: workSchedule.workHours,
        )
      : null;
  if (workStats != null) {
    AnalyticsPipelineValidation.logWarnings(
      'mobility',
      AnalyticsPipelineValidation.validateWorkAttendance(workStats),
    );
  }

  final calendarEvents = listMajorCalendarEvents(calendar);
  final expenseEvents = listExpenseAssociationCalendarEvents(calendar);
  if (expenses.transactions.isNotEmpty) {
    AnalyticsPipelineValidation.logWarnings(
      'expenses',
      AnalyticsPipelineValidation.validateEventAttributions(
        transactions: expenses.transactions,
        calendarEvents: expenseEvents,
      ),
    );
  }
  const double? resolvedBudget = null;
  final monthlyIncome = expenses.totalIncome;
  final fuel = mobilityFuelSummaryFromExpenses(expenses);
  final cyclingGoal = _cyclingMetrics(
    current: location,
    previous: previousLocation,
  );
  final gamingTrend = _gamingTrendMetrics(
    current: gameActivity,
    previous: previousGameActivity,
  );

  final stableMonth = healthSummary != null && expenses.transactions.isNotEmpty
      ? _stableMonthSection(
          evaluateStableMonth(
            selection: AnalysisSourceSelection.all(),
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
    health: healthSummary == null ? null : _healthAnalysis(healthSummary),
    financial: expenses.transactions.isEmpty
        ? null
        : _financialAnalysis(
            expenses: expenses,
            monthlyBudget: resolvedBudget,
            monthlyIncome: monthlyIncome,
          ),
    mobility:
        location.activities.isEmpty && !(workStats?.hasWorkVisits ?? false)
        ? null
        : _mobilityAnalysis(
            location: location,
            workStats: workStats,
            fuel: fuel,
            cyclingGoal: cyclingGoal,
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

DashboardHealthAnalysis _healthAnalysis(MonthlyHealthSummary summary) {
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

  return DashboardHealthAnalysis(
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
}) {
  final totalSpent = expenses.totalRealExpenses;
  AnalyticsPipelineValidation.logWarnings(
    'expenses',
    AnalyticsPipelineValidation.validateExpenseMetrics(
      summary: expenses,
      monthlyIncome: monthlyIncome,
      monthlyBudget: monthlyBudget,
    ),
  );
  final categories = expenses.expensesByCategory;
  final top = categories.isEmpty ? null : categories.first;
  final top3Total = categories
      .take(3)
      .fold<double>(0, (sum, category) => sum + category.total);

  return DashboardFinancialAnalysis(
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
  required ({double? distanceKm, double? changeKm}) cyclingGoal,
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
    cyclingDistanceKm: cyclingGoal.distanceKm,
    cyclingDistanceChangeKm: cyclingGoal.changeKm,
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

DashboardDomainStatus _healthStatus(MonthlyHealthSummary? summary) {
  if (summary == null) {
    return const DashboardDomainStatus(
      id: 'health',
      label: 'Health',
      iconName: 'health',
      hasData: false,
      headline: 'No sleep data',
      detail: 'Import from Health screen',
    );
  }

  final debt = computeSleepDebt(
    summary.dailySleep.where((night) => night.hasData).toList(),
  );
  return DashboardDomainStatus(
    id: 'health',
    label: 'Health',
    iconName: 'health',
    hasData: true,
    headline: debt.nightsBelowTarget > 0
        ? '${debt.nightsBelowTarget} nights below 7h'
        : '${summary.sleepNightsTracked} nights tracked',
    detail: debt.estimatedDebt > Duration.zero
        ? '${formatDebtDuration(debt.estimatedDebt)} sleep debt'
        : 'On sleep target',
  );
}

DashboardDomainStatus _expensesStatus(
  ExpensesSummary summary,
  double? monthlyBudget,
  double monthlyIncome,
) {
  if (summary.transactions.isEmpty) {
    return const DashboardDomainStatus(
      id: 'expenses',
      label: 'Expenses',
      iconName: 'expenses',
      hasData: false,
      headline: 'No transactions',
      detail: 'Sync Cashew from Expenses',
    );
  }

  final budgetPct = monthlyBudget != null && monthlyBudget > 0
      ? DerivedMetricValidation.sanitizePercent(
          summary.totalRealExpenses / monthlyBudget * 100,
        )
      : null;

  return DashboardDomainStatus(
    id: 'expenses',
    label: 'Expenses',
    iconName: 'expenses',
    hasData: true,
    headline: budgetPct != null
        ? '${budgetPct.toStringAsFixed(0)}% budget used'
        : _formatMoney(summary.totalRealExpenses, summary.currency),
    detail: monthlyIncome > 0
        ? '${DerivedMetricValidation.sanitizePercent(summary.totalRealExpenses / monthlyIncome * 100)?.toStringAsFixed(0) ?? '—'}% of income'
        : '${summary.realExpenseCount} expense lines',
  );
}

DashboardDomainStatus _locationStatus(
  LocationSummary summary,
  WorkArrivalStats? workStats,
) {
  if (summary.activities.isEmpty && !(workStats?.hasWorkVisits ?? false)) {
    return const DashboardDomainStatus(
      id: 'location',
      label: 'Location',
      iconName: 'location',
      hasData: false,
      headline: 'No mobility data',
      detail: 'Import Google Timeline',
    );
  }

  final lateRate = workStats?.lateArrivalRate;
  return DashboardDomainStatus(
    id: 'location',
    label: 'Location',
    iconName: 'location',
    hasData: true,
    headline: lateRate != null && workStats!.lateArrivalCount > 0
        ? '${lateRate.toStringAsFixed(0)}% late arrivals'
        : '${(summary.periodMotorcycleDistanceMeters / 1000).toStringAsFixed(1)} km',
    detail: workStats != null && workStats.hasWorkVisits
        ? '${workStats.totalWorkDays} work days tracked'
        : '${summary.activities.length} activities',
  );
}

DashboardDomainStatus _gamingStatus(
  GameActivitySummary summary,
  ({int? sessionChange, double? playTimeChangeHours}) trend,
) {
  if (summary.sessions.isEmpty) {
    return const DashboardDomainStatus(
      id: 'gaming',
      label: 'Gaming',
      iconName: 'gaming',
      hasData: false,
      headline: 'No sessions',
      detail: 'Import GameActivity export',
    );
  }

  final change = trend.sessionChange;
  return DashboardDomainStatus(
    id: 'gaming',
    label: 'Gaming',
    iconName: 'gaming',
    hasData: true,
    headline: _formatPlayHours(summary.totalPlayTime),
    detail: change != null
        ? '${change >= 0 ? '+' : ''}$change sessions vs prior month'
        : '${summary.sessions.length} sessions',
  );
}

DashboardDomainStatus _calendarStatus(
  CalendarSummary summary,
  List<MajorCalendarEvent> majorEvents,
) {
  if (summary.events.isEmpty) {
    return const DashboardDomainStatus(
      id: 'calendar',
      label: 'Calendar',
      iconName: 'calendar',
      hasData: false,
      headline: 'No events',
      detail: 'Sync Google Calendar',
    );
  }

  return DashboardDomainStatus(
    id: 'calendar',
    label: 'Calendar',
    iconName: 'calendar',
    hasData: true,
    headline: '${majorEvents.length} major events',
    detail:
        '${summary.events.where((event) => event.isHoliday).length} holidays',
  );
}

({double? distanceKm, double? changeKm}) _cyclingMetrics({
  required LocationSummary current,
  LocationSummary? previous,
}) {
  if (!current.hasAnyData) {
    return (distanceKm: null, changeKm: null);
  }

  final currentTrips = current.periodMotorcyclingActivities
      .where((trip) => trip.distanceMeters > 0)
      .toList();
  if (currentTrips.isEmpty) return (distanceKm: null, changeKm: null);

  final currentKm =
      currentTrips.fold<double>(0, (sum, trip) => sum + trip.distanceMeters) /
      1000;

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
  final symbol = currency == 'BDT'
      ? '৳'
      : (currency.isEmpty ? '' : '$currency ');
  return '$symbol${amount.toStringAsFixed(0)}';
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
