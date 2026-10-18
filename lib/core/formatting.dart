import 'package:intl/intl.dart';

double roundTo1dp(double value) => (value * 10).roundToDouble() / 10;

double roundTo2dp(double value) => (value * 100).roundToDouble() / 100;

String formatPercent1dp(double percent) {
  return '${roundTo1dp(percent).toStringAsFixed(1)}%';
}

String formatSignedPercentChange(double change) {
  final sign = change >= 0 ? '+' : '';
  return '$sign${roundTo1dp(change).toStringAsFixed(1)}%';
}

String formatSignedPercentagePointsChange(double change) {
  final sign = change >= 0 ? '+' : '';
  return '$sign${roundTo1dp(change).toStringAsFixed(1)} percentage points';
}

/// Short "5 min ago" style label for [when].
String relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return DateFormat('d MMM').format(when);
}

final _grouped = NumberFormat.decimalPattern();

/// `12,345 km`, rounded to whole km.
String formatKm(double km) => '${_grouped.format(km.round())} km';

/// `$1,234`, or `$12.50` when the amount has cents worth showing.
String formatMoney(String symbol, double amount) {
  final whole = amount.abs() >= 100 || amount == amount.roundToDouble();
  final text = whole
      ? _grouped.format(amount.round())
      : amount.toStringAsFixed(2);
  return '$symbol$text';
}

/// Parses user-typed numbers, allowing thousands separators.
double? parseNumber(String text) =>
    double.tryParse(text.replaceAll(',', '').trim());
