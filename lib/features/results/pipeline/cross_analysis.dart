import 'package:personal/features/forecasts/life/life_forecast_math.dart';

/// Per-day series from every source, keyed by local midnight. A key is
/// present only when the source recorded that day (zero-filled series such as
/// gaming and spending are filled by the caller for the days it covers).
class CrossInputs {
  const CrossInputs({
    this.sleepHours = const {},
    this.steps = const {},
    this.restingHr = const {},
    this.gamingHours = const {},
    this.screenHours = const {},
    this.spend = const {},
    this.eventHours = const {},
    this.lateDays = const {},
    this.onTimeDays = const {},
    this.currency = '',
  });

  /// Hours slept, keyed by the day the sleep ended (the wake date).
  final Map<DateTime, double> sleepHours;
  final Map<DateTime, double> steps;
  final Map<DateTime, double> restingHr;
  final Map<DateTime, double> gamingHours;
  final Map<DateTime, double> screenHours;
  final Map<DateTime, double> spend;
  final Map<DateTime, double> eventHours;

  /// Work days you arrived late / on time.
  final Set<DateTime> lateDays;
  final Set<DateTime> onTimeDays;
  final String currency;
}

enum CrossTone { good, watch, neutral }

class CrossInsight {
  const CrossInsight({
    required this.title,
    required this.detail,
    required this.tone,
    required this.notable,
    required this.days,
    this.r,
  });

  final String title;
  final String detail;
  final CrossTone tone;

  /// False when the data shows no clear link (still reported, but quietly).
  final bool notable;
  final int days;
  final double? r;
}

class _Metric {
  const _Metric(this.name, this.format);

  final String name;
  final String Function(double) format;
}

String _hours(double v) => hoursLabel(v);
String _steps(double v) => '${(v / 1000).toStringAsFixed(1)}k steps';
String _bpm(double v) => '${v.round()} bpm';

DateTime _shift(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

const _minDays = 8;
const _notableR = 0.3;

/// Every cross-source link the data can support, notable ones first.
List<CrossInsight> computeCrossInsights(CrossInputs i) {
  final money = _Metric('spending', (v) => moneyLabel(v, i.currency));
  const sleepM = _Metric('sleep', _hours);
  const stepsM = _Metric('steps', _steps);
  const hrM = _Metric('resting heart rate', _bpm);
  const screenM = _Metric('screen time', _hours);
  const gameM = _Metric('gaming', _hours);
  const loadM = _Metric('booked calendar time', _hours);

  final out = <CrossInsight?>[
    _link(
      'Screen time → sleep',
      i.screenHours,
      screenM,
      i.sleepHours,
      sleepM,
      lag: 1,
      yLabel: 'the next night\'s sleep',
      yHigherBetter: true,
    ),
    _link(
      'Gaming → sleep',
      i.gamingHours,
      gameM,
      i.sleepHours,
      sleepM,
      lag: 1,
      yLabel: 'the next night\'s sleep',
      yHigherBetter: true,
    ),
    _link(
      'Activity → sleep',
      i.steps,
      stepsM,
      i.sleepHours,
      sleepM,
      lag: 1,
      yLabel: 'the next night\'s sleep',
      yHigherBetter: true,
    ),
    _link(
      'Busy calendar → sleep',
      i.eventHours,
      loadM,
      i.sleepHours,
      sleepM,
      lag: 1,
      yLabel: 'the next night\'s sleep',
      yHigherBetter: true,
    ),
    _link(
      'Sleep → spending',
      i.sleepHours,
      sleepM,
      i.spend,
      money,
      yLabel: 'that day\'s spending',
      yHigherBetter: false,
    ),
    _link(
      'Screen time → spending',
      i.screenHours,
      screenM,
      i.spend,
      money,
      yLabel: 'that day\'s spending',
      yHigherBetter: false,
    ),
    _link(
      'Sleep → movement',
      i.sleepHours,
      sleepM,
      i.steps,
      stepsM,
      yLabel: 'that day\'s steps',
      yHigherBetter: true,
    ),
    _link(
      'Screen time → movement',
      i.screenHours,
      screenM,
      i.steps,
      stepsM,
      yLabel: 'that day\'s steps',
      yHigherBetter: true,
    ),
    _link(
      'Sleep → resting heart rate',
      i.sleepHours,
      sleepM,
      i.restingHr,
      hrM,
      yLabel: 'that day\'s resting heart rate',
      yHigherBetter: false,
    ),
    _lateness(
      'Sleep → late arrivals',
      i,
      i.sleepHours,
      0,
      'sleep the night before',
      _hours,
      lowerIsRisk: true,
    ),
    _lateness(
      'Screen time → late arrivals',
      i,
      i.screenHours,
      -1,
      'screen time the day before',
      _hours,
      lowerIsRisk: false,
    ),
  ].whereType<CrossInsight>().toList();

  out.sort((a, b) {
    if (a.notable != b.notable) return a.notable ? -1 : 1;
    return (b.r?.abs() ?? 0).compareTo(a.r?.abs() ?? 0);
  });
  return out;
}

CrossInsight? _link(
  String title,
  Map<DateTime, double> x,
  _Metric xm,
  Map<DateTime, double> y,
  _Metric ym, {
  int lag = 0,
  required String yLabel,
  required bool yHigherBetter,
}) {
  final xs = <double>[];
  final ys = <double>[];
  for (final e in x.entries) {
    final other = y[_shift(e.key, lag)];
    if (other == null) continue;
    xs.add(e.value);
    ys.add(other);
  }
  if (xs.length < _minDays) return null;
  final r = pearson(xs, ys);
  if (r == null) return null;

  final cut = median(xs);
  var hi = <double>[];
  var lo = <double>[];
  for (var k = 0; k < xs.length; k++) {
    (xs[k] > cut ? hi : lo).add(ys[k]);
  }
  if (hi.length < 3 || lo.length < 3) {
    hi = [];
    lo = [];
    for (var k = 0; k < xs.length; k++) {
      (xs[k] >= cut ? hi : lo).add(ys[k]);
    }
  }
  final notable = r.abs() >= _notableR;
  final rText = 'r = ${r.toStringAsFixed(2)}, ${xs.length} days';
  if (!notable || hi.length < 3 || lo.length < 3) {
    return CrossInsight(
      title: title,
      detail: 'No clear link between ${xm.name} and $yLabel ($rText).',
      tone: CrossTone.neutral,
      notable: false,
      days: xs.length,
      r: r,
    );
  }
  final hiMean = mean(hi);
  final loMean = mean(lo);
  final delta = hiMean - loMean;
  final favourable = (delta > 0) == yHigherBetter;
  return CrossInsight(
    title: title,
    detail:
        'On days above ${xm.format(cut)} of ${xm.name}, $yLabel averaged '
        '${ym.format(hiMean)} against ${ym.format(loMean)} on other days '
        '($rText).',
    tone: favourable ? CrossTone.good : CrossTone.watch,
    notable: true,
    days: xs.length,
    r: r,
  );
}

/// Compares a day-level figure on late work days with on-time work days.
/// [dayOffset] picks which day's figure to use relative to the work day.
CrossInsight? _lateness(
  String title,
  CrossInputs i,
  Map<DateTime, double> series,
  int dayOffset,
  String label,
  String Function(double) format, {
  required bool lowerIsRisk,
}) {
  double? at(DateTime d) => series[_shift(d, dayOffset)];
  final late = [for (final d in i.lateDays) ?at(d)];
  final onTime = [for (final d in i.onTimeDays) ?at(d)];
  if (late.length < 3 || onTime.length < 3) return null;
  final lateMean = mean(late);
  final onMean = mean(onTime);
  final diff = lateMean - onMean;
  final spread = stdDev([...late, ...onTime]);
  final notable = spread > 0 && diff.abs() / spread >= 0.4;
  final worse = lowerIsRisk ? diff < 0 : diff > 0;
  return CrossInsight(
    title: title,
    detail: notable
        ? 'On the ${late.length} days you were late, $label averaged '
              '${format(lateMean)}, against ${format(onMean)} when on time.'
        : 'No clear link between $label and arriving late '
              '(${late.length} late vs ${onTime.length} on-time days).',
    tone: !notable
        ? CrossTone.neutral
        : worse
        ? CrossTone.watch
        : CrossTone.good,
    notable: notable,
    days: late.length + onTime.length,
  );
}

/// Plain text of the notable links, for the export and AI prompts.
String crossInsightsToText(List<CrossInsight> insights) {
  final notable = insights.where((e) => e.notable).toList();
  if (insights.isEmpty) {
    return 'Not enough overlapping days across sources to compare.';
  }
  final out = StringBuffer();
  for (final e in notable) {
    out.writeln('- ${e.title}: ${e.detail}');
  }
  final quiet = insights.where((e) => !e.notable).map((e) => e.title);
  if (quiet.isNotEmpty) {
    out.writeln('- No clear link found for: ${quiet.join(', ')}.');
  }
  return out.toString().trimRight();
}

/// Builds [CrossInputs] from day-keyed lists; midnight-normalises the keys.
Map<DateTime, double> dayMap(
  Iterable<({DateTime date, double value})> rows, {
  bool sum = false,
}) {
  final out = <DateTime, double>{};
  for (final r in rows) {
    final l = r.date.toLocal();
    final k = DateTime(l.year, l.month, l.day);
    out[k] = sum ? (out[k] ?? 0) + r.value : r.value;
  }
  return out;
}
