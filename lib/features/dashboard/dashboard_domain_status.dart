part of 'dashboard_view_data.dart';

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
