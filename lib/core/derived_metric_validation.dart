import 'dart:math' as math;

import 'package:personal/core/formatting.dart';

/// Validates and sanitizes derived metric values before display.
class DerivedMetricValidation {
  const DerivedMetricValidation._();

  static const maxCircularStdDevMinutes = 12 * 60;

  static double? sanitizePercent(
    double? value, {
    double min = 0,
    double max = 1000,
  }) {
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value < min || value > max) return null;
    return roundTo1dp(value);
  }

  static double? sanitizeCircularStdDevMinutes(double value) {
    if (value.isNaN || value.isInfinite || value < 0) return null;
    if (value > maxCircularStdDevMinutes) return null;
    return value;
  }

  static double? sanitizeClusterDensity(double density) {
    return sanitizePercent(density, max: 100);
  }

  static int? sanitizeNonNegativeInt(int value) {
    if (value < 0) return null;
    return value;
  }

  static String formatValidatedPercent(double? percent) {
    final valid = sanitizePercent(percent);
    if (valid == null) return 'n/a';
    return '${valid.toStringAsFixed(1)}%';
  }

  static String formatValidatedStdDevMinutes(double minutes) {
    final valid = sanitizeCircularStdDevMinutes(minutes);
    if (valid == null) return 'n/a';
    return '${valid.round()} min';
  }

  static String formatValidatedClusterDensity(double density) {
    final valid = sanitizeClusterDensity(density);
    if (valid == null) return 'n/a';
    return '${valid.toStringAsFixed(1)}%';
  }
}

/// Circular standard deviation for clock times (handles midnight crossover).
double circularStdDevClockMinutes(Iterable<int> clockMinutes) {
  final list = clockMinutes
      .map((minutes) => ((minutes % (24 * 60)) + 24 * 60) % (24 * 60))
      .toList();
  if (list.length < 2) return 0;

  final radians = list.map((v) => v / (24 * 60) * 2 * math.pi).toList();
  final sinSum = radians.map(math.sin).reduce((a, b) => a + b);
  final cosSum = radians.map(math.cos).reduce((a, b) => a + b);
  final meanResultant =
      math.sqrt(sinSum * sinSum + cosSum * cosSum) / list.length;
  if (meanResultant <= 0) return 0;

  final circularVariance = (1 - meanResultant).clamp(0.0, 1.0);
  if (circularVariance <= 0) return 0;

  final stdDevRadians = math.sqrt(-2 * math.log(meanResultant));
  final stdDevMinutes = stdDevRadians * 24 * 60 / (2 * math.pi);
  return DerivedMetricValidation.sanitizeCircularStdDevMinutes(stdDevMinutes) ??
      0;
}

int circularMeanClockMinutes(Iterable<int> clockMinutes) {
  final list = clockMinutes
      .map((minutes) => ((minutes % (24 * 60)) + 24 * 60) % (24 * 60))
      .toList();
  if (list.isEmpty) return 0;

  final radians = list.map((v) => v / (24 * 60) * 2 * math.pi).toList();
  final sinSum = radians.map(math.sin).reduce((a, b) => a + b);
  final cosSum = radians.map(math.cos).reduce((a, b) => a + b);
  final meanAngle = math.atan2(sinSum / list.length, cosSum / list.length);
  final normalized = meanAngle < 0 ? meanAngle + 2 * math.pi : meanAngle;
  return (normalized * 24 * 60 / (2 * math.pi)).round() % (24 * 60);
}
