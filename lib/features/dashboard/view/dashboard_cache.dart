import 'package:personal/core/app_log.dart';
import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/core/storage/json_file_cache.dart';
import 'package:personal/features/dashboard/view/dashboard_view_data.dart';
import 'package:personal/features/results/pipeline/cross_analysis.dart';

const _cacheKey = 'data_cache_dashboard_v1';
const _schema = 2;

/// Last computed dashboard, so Home shows its tiles the instant the app opens
/// instead of waiting on Health Connect and the previous-month comparisons.
abstract final class DashboardCache {
  /// The cached view for [period]'s month, or null when absent or for another
  /// month (an old month's tiles would be wrong).
  static Future<DashboardViewData?> load(AnalysisPeriod period) async {
    final map = await JsonFileCache.instance.read(_cacheKey);
    if (map == null || map['schema'] != _schema) return null;
    try {
      final data = _viewFromJson(map);
      return data.period.dataMonthStart == period.dataMonthStart ? data : null;
    } catch (e) {
      AppLog.warn('Failed to load dashboard cache: $e');
      return null;
    }
  }

  static Future<void> save(DashboardViewData data) async {
    try {
      await JsonFileCache.instance.write(_cacheKey, _viewToJson(data));
    } catch (e) {
      AppLog.warn('Failed to save dashboard cache: $e');
    }
  }
}

Map<String, dynamic> _viewToJson(DashboardViewData d) => {
  'schema': _schema,
  'start': d.period.dataMonthStart.toIso8601String(),
  'end': d.period.dataMonthEnd.toIso8601String(),
  'periodLabel': d.periodLabel,
  'domains': [for (final x in d.domains) _domainToJson(x)],
  'stable': _opt(d.stableMonth, _stableToJson),
  'health': _opt(d.health, _healthToJson),
  'financial': _opt(d.financial, _financialToJson),
  'mobility': _opt(d.mobility, _mobilityToJson),
  'gaming': _opt(d.gaming, _gamingToJson),
  'calendar': _opt(d.calendar, _calendarToJson),
  'screen': _opt(d.screenTime, _screenToJson),
  'cross': [for (final c in d.crossInsights) _crossToJson(c)],
  'detail': d.adviceDetail,
};

DashboardViewData _viewFromJson(Map<String, dynamic> j) => DashboardViewData(
  period: AnalysisPeriod(
    dataMonthStart: DateTime.parse(j['start'] as String),
    dataMonthEnd: DateTime.parse(j['end'] as String),
  ),
  periodLabel: j['periodLabel'] as String,
  domains: _list(j['domains'], _domainFromJson),
  stableMonth: _optFrom(j['stable'], _stableFromJson),
  health: _optFrom(j['health'], _healthFromJson),
  financial: _optFrom(j['financial'], _financialFromJson),
  mobility: _optFrom(j['mobility'], _mobilityFromJson),
  gaming: _optFrom(j['gaming'], _gamingFromJson),
  calendar: _optFrom(j['calendar'], _calendarFromJson),
  screenTime: _optFrom(j['screen'], _screenFromJson),
  crossInsights: _list(j['cross'], _crossFromJson),
  adviceDetail: j['detail'] as String? ?? '',
);

Map<String, dynamic>? _opt<T>(T? v, Map<String, dynamic> Function(T) f) =>
    v == null ? null : f(v);

T? _optFrom<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
    raw is Map ? f(raw.cast<String, dynamic>()) : null;

List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) f) => raw is List
    ? [
        for (final e in raw.whereType<Map<dynamic, dynamic>>())
          f(e.cast<String, dynamic>()),
      ]
    : <T>[];

double? _d(Object? v) => (v as num?)?.toDouble();
int? _i(Object? v) => (v as num?)?.toInt();

Map<String, dynamic> _barToJson(DashboardBarItem b) => {
  'label': b.label,
  'value': b.value,
  'display': b.displayValue,
};
DashboardBarItem _barFromJson(Map<String, dynamic> j) => DashboardBarItem(
  label: j['label'] as String,
  value: _d(j['value'])!,
  displayValue: j['display'] as String,
);
List<Map<String, dynamic>> _bars(List<DashboardBarItem> l) => [
  for (final b in l) _barToJson(b),
];

Map<String, dynamic> _domainToJson(DashboardDomainStatus s) => {
  'id': s.id,
  'label': s.label,
  'icon': s.iconName,
  'hasData': s.hasData,
  'headline': s.headline,
  'detail': s.detail,
};
DashboardDomainStatus _domainFromJson(Map<String, dynamic> j) =>
    DashboardDomainStatus(
      id: j['id'] as String,
      label: j['label'] as String,
      iconName: j['icon'] as String,
      hasData: j['hasData'] as bool,
      headline: j['headline'] as String,
      detail: j['detail'] as String,
    );

Map<String, dynamic> _stableToJson(DashboardStableMonthSection s) => {
  'canEvaluate': s.canEvaluate,
  'isStable': s.isStable,
  'shortSleepNights': s.shortSleepNights,
  'sleepDebtHours': s.sleepDebtHours,
  'largestCategoryName': s.largestCategoryName,
  'largestCategoryIncomeShare': s.largestCategoryIncomeShare,
  'severe': s.hasSevereAnomalyCluster,
  'severeLabel': s.severeClusterLabel,
};
DashboardStableMonthSection _stableFromJson(Map<String, dynamic> j) =>
    DashboardStableMonthSection(
      canEvaluate: j['canEvaluate'] as bool,
      isStable: j['isStable'] as bool,
      shortSleepNights: _i(j['shortSleepNights'])!,
      sleepDebtHours: _d(j['sleepDebtHours'])!,
      largestCategoryName: j['largestCategoryName'] as String?,
      largestCategoryIncomeShare: _d(j['largestCategoryIncomeShare']),
      hasSevereAnomalyCluster: j['severe'] as bool,
      severeClusterLabel: j['severeLabel'] as String?,
    );

Map<String, dynamic> _healthToJson(DashboardHealthAnalysis h) => {
  'nights': h.nightsTracked,
  'below': h.nightsBelowTarget,
  'debt': h.sleepDebtHours,
  'bed': h.bedtimeStdDevMinutes,
  'wake': h.wakeStdDevMinutes,
  'recovery': h.recoveryRatePercent,
  'clusters': _bars(h.clusters),
  'daily': _bars(h.dailySleep),
  'debtChange': h.sleepDebtChangeHours,
};
DashboardHealthAnalysis _healthFromJson(Map<String, dynamic> j) =>
    DashboardHealthAnalysis(
      nightsTracked: _i(j['nights'])!,
      nightsBelowTarget: _i(j['below'])!,
      sleepDebtHours: _d(j['debt'])!,
      bedtimeStdDevMinutes: _d(j['bed']),
      wakeStdDevMinutes: _d(j['wake']),
      recoveryRatePercent: _d(j['recovery']),
      clusters: _list(j['clusters'], _barFromJson),
      dailySleep: _list(j['daily'], _barFromJson),
      sleepDebtChangeHours: _d(j['debtChange']),
    );

Map<String, dynamic> _financialToJson(DashboardFinancialAnalysis f) => {
  'currency': f.currency,
  'spent': f.totalSpent,
  'income': f.totalIncome,
  'net': f.netSurplus,
  'budget': f.monthlyBudget,
  'budgetPct': f.budgetConsumedPercent,
  'incomePct': f.incomeUtilizationPercent,
  'burn': f.burnRatePercent,
  'topName': f.topCategoryName,
  'topShare': f.topCategorySharePercent,
  'top3Share': f.top3CategorySharePercent,
  'concentration': _bars(f.categoryConcentration),
  'spentChange': f.spentChangePercent,
};
DashboardFinancialAnalysis _financialFromJson(Map<String, dynamic> j) =>
    DashboardFinancialAnalysis(
      currency: j['currency'] as String,
      totalSpent: _d(j['spent'])!,
      totalIncome: _d(j['income'])!,
      netSurplus: _d(j['net'])!,
      monthlyBudget: _d(j['budget']),
      budgetConsumedPercent: _d(j['budgetPct']),
      incomeUtilizationPercent: _d(j['incomePct']),
      burnRatePercent: _d(j['burn']),
      topCategoryName: j['topName'] as String?,
      topCategorySharePercent: _d(j['topShare']),
      top3CategorySharePercent: _d(j['top3Share']),
      categoryConcentration: _list(j['concentration'], _barFromJson),
      spentChangePercent: _d(j['spentChange']),
    );

Map<String, dynamic> _mobilityToJson(DashboardMobilityAnalysis m) => {
  'km': m.motorcycleKm,
  'travelH': m.travelTimeHours,
  'workDays': m.workDays,
  'late': m.lateArrivals,
  'lateRate': m.lateArrivalRatePercent,
  'delay': m.averageDelayMinutes,
  'fuelSpend': m.fuelSpend,
  'refuels': m.fuelRefuelCount,
  'litres': m.fuelLitres,
  'rate': m.fuelRatePerLitre,
  'priced': m.fuelPricedRefuelCount,
  'fuelCurrency': m.fuelCurrency,
  'transport': _bars(m.byTransport),
  'ride': m.rideDistanceKm,
  'rideChange': m.rideDistanceChangeKm,
};
DashboardMobilityAnalysis _mobilityFromJson(Map<String, dynamic> j) =>
    DashboardMobilityAnalysis(
      motorcycleKm: _d(j['km'])!,
      travelTimeHours: _d(j['travelH'])!,
      workDays: _i(j['workDays'])!,
      lateArrivals: _i(j['late'])!,
      lateArrivalRatePercent: _d(j['lateRate']),
      averageDelayMinutes: _d(j['delay']),
      fuelSpend: _d(j['fuelSpend']),
      fuelRefuelCount: _i(j['refuels']),
      fuelLitres: _d(j['litres']),
      fuelRatePerLitre: _d(j['rate']),
      fuelPricedRefuelCount: _i(j['priced']),
      fuelCurrency: (j['fuelCurrency'] as String?) ?? '',
      byTransport: _list(j['transport'], _barFromJson),
      rideDistanceKm: _d(j['ride']),
      rideDistanceChangeKm: _d(j['rideChange']),
    );

Map<String, dynamic> _gamingToJson(DashboardGamingAnalysis g) => {
  'sessions': g.sessionCount,
  'hours': g.totalPlayHours,
  'sessionChange': g.sessionChange,
  'hoursChange': g.playTimeChangeHours,
  'byGame': _bars(g.byGame),
};
DashboardGamingAnalysis _gamingFromJson(Map<String, dynamic> j) =>
    DashboardGamingAnalysis(
      sessionCount: _i(j['sessions'])!,
      totalPlayHours: _d(j['hours'])!,
      sessionChange: _i(j['sessionChange']),
      playTimeChangeHours: _d(j['hoursChange']),
      byGame: _list(j['byGame'], _barFromJson),
    );

Map<String, dynamic> _calendarToJson(DashboardCalendarAnalysis c) => {
  'major': c.majorEventCount,
  'holidays': c.holidayCount,
  'linked': c.expenseLinkedEventCount,
  'weekday': _bars(c.byWeekday),
};
DashboardCalendarAnalysis _calendarFromJson(Map<String, dynamic> j) =>
    DashboardCalendarAnalysis(
      majorEventCount: _i(j['major'])!,
      holidayCount: _i(j['holidays'])!,
      expenseLinkedEventCount: _i(j['linked'])!,
      byWeekday: _list(j['weekday'], _barFromJson),
    );

Map<String, dynamic> _screenToJson(DashboardScreenTimeAnalysis s) => {
  'total': s.totalHours,
  'avg': s.avgHoursPerDay,
  'days': s.daysTracked,
  'apps': _bars(s.topApps),
  'change': s.avgChangeHours,
  'heavyLabel': s.heaviestDayLabel,
  'heavyHours': s.heaviestDayHours,
};
DashboardScreenTimeAnalysis _screenFromJson(Map<String, dynamic> j) =>
    DashboardScreenTimeAnalysis(
      totalHours: _d(j['total'])!,
      avgHoursPerDay: _d(j['avg'])!,
      daysTracked: _i(j['days'])!,
      topApps: _list(j['apps'], _barFromJson),
      avgChangeHours: _d(j['change']),
      heaviestDayLabel: j['heavyLabel'] as String?,
      heaviestDayHours: _d(j['heavyHours']),
    );

Map<String, dynamic> _crossToJson(CrossInsight c) => {
  'title': c.title,
  'detail': c.detail,
  'tone': c.tone.name,
  'notable': c.notable,
  'days': c.days,
  'r': c.r,
};
CrossInsight _crossFromJson(Map<String, dynamic> j) => CrossInsight(
  title: j['title'] as String,
  detail: j['detail'] as String,
  tone: CrossTone.values.byName(j['tone'] as String),
  notable: j['notable'] as bool,
  days: _i(j['days'])!,
  r: _d(j['r']),
);
