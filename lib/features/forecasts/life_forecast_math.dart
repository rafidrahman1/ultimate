import 'dart:math' as math;

import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';

DateTime dayOf(DateTime d) {
  final local = d.toLocal();
  return DateTime(local.year, local.month, local.day);
}

final DateFormat dateLine = DateFormat('yyyy-MM-dd (EEE)');
final DateFormat shortDate = DateFormat('MMM d');

double mean(Iterable<num> values) {
  final list = values.toList();
  if (list.isEmpty) return 0;
  return list.fold<double>(0, (a, b) => a + b) / list.length;
}

double median(Iterable<num> values) {
  final list = values.map((v) => v.toDouble()).toList()..sort();
  if (list.isEmpty) return 0;
  final mid = list.length ~/ 2;
  return list.length.isOdd ? list[mid] : (list[mid - 1] + list[mid]) / 2;
}

/// Exponentially weighted mean, newest value last in [values].
double ewma(List<double> values, {double alpha = 0.3}) {
  if (values.isEmpty) return 0;
  var out = values.first;
  for (final v in values.skip(1)) {
    out = alpha * v + (1 - alpha) * out;
  }
  return out;
}

/// Least-squares slope of [y] over [x]; null with fewer than two distinct x.
double? slope(List<double> x, List<double> y) {
  if (x.length != y.length || x.length < 2) return null;
  final mx = mean(x);
  final my = mean(y);
  var num_ = 0.0;
  var den = 0.0;
  for (var i = 0; i < x.length; i++) {
    num_ += (x[i] - mx) * (y[i] - my);
    den += (x[i] - mx) * (x[i] - mx);
  }
  return den == 0 ? null : num_ / den;
}

/// Pearson correlation; null when either side has no spread.
double? pearson(List<double> x, List<double> y) {
  if (x.length != y.length || x.length < 3) return null;
  final mx = mean(x);
  final my = mean(y);
  var cov = 0.0;
  var vx = 0.0;
  var vy = 0.0;
  for (var i = 0; i < x.length; i++) {
    cov += (x[i] - mx) * (y[i] - my);
    vx += (x[i] - mx) * (x[i] - mx);
    vy += (y[i] - my) * (y[i] - my);
  }
  if (vx == 0 || vy == 0) return null;
  return cov / math.sqrt(vx * vy);
}

String hoursLabel(double hours) {
  final total = (hours * 60).round();
  final h = total ~/ 60;
  final m = total % 60;
  return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}m';
}

/// "HH:mm" from minutes since midnight (wraps past 24h).
String clockLabel(num minutes) {
  final m = ((minutes.round() % 1440) + 1440) % 1440;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

String signed(double value, {int digits = 1}) =>
    '${value >= 0 ? '+' : '−'}${value.abs().toStringAsFixed(digits)}';

/// A short fingerprint of the numbers a forecast was built from.
String fingerprint(Iterable<Object?> parts) =>
    parts.map((p) => p is double ? p.toStringAsFixed(2) : '$p').join('|');

/// A whole-number amount with the currency prefix, e.g. "৳1,200".
String moneyLabel(double amount, String currency) {
  final text = NumberFormat.decimalPattern().format(amount.abs().round());
  return '${amount < 0 ? '−' : ''}${currencyPrefix(currency)}$text';
}

/// Std deviation of [values]; 0 when fewer than two.
double stdDev(Iterable<num> values) {
  final list = values.map((v) => v.toDouble()).toList();
  if (list.length < 2) return 0;
  final m = mean(list);
  return math.sqrt(
    list.fold<double>(0, (a, v) => a + (v - m) * (v - m)) / list.length,
  );
}

String weekdayShort(DateTime d) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];
