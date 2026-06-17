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
