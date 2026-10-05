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

String formatBdt(double amount) => roundTo2dp(amount).toStringAsFixed(2);

/// Display prefix for a currency code: `৳` for BDT, otherwise `"USD "`.
String currencyPrefix(String currency) {
  if (currency == 'BDT') return '৳';
  return currency.isEmpty ? '' : '$currency ';
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
