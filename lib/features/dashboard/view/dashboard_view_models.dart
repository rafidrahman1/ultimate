part of 'dashboard_view_data.dart';

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
    this.sleepDebtChangeHours,
  });

  /// Sleep debt minus the same span last month; negative is better.
  final double? sleepDebtChangeHours;

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
    this.spentChangePercent,
  });

  /// Spending vs the same span last month, in percent; negative is better.
  final double? spentChangePercent;
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
    this.fuelLitres,
    this.fuelRatePerLitre,
    this.fuelPricedRefuelCount,
    this.fuelCurrency = '',
    required this.byTransport,
    this.rideDistanceKm,
    this.rideDistanceChangeKm,
  });

  final double motorcycleKm;
  final double travelTimeHours;
  final int workDays;
  final int lateArrivals;
  final double? lateArrivalRatePercent;
  final double? averageDelayMinutes;
  final double? fuelSpend;
  final int? fuelRefuelCount;

  /// Litres bought, from refuels whose description has a price per litre.
  final double? fuelLitres;
  final double? fuelRatePerLitre;
  final int? fuelPricedRefuelCount;
  final String fuelCurrency;
  final List<DashboardBarItem> byTransport;
  final double? rideDistanceKm;
  final double? rideDistanceChangeKm;
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
