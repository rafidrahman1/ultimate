/// Change against the same span last month, shown as a small arrow chip.
class DashboardDelta {
  const DashboardDelta({
    required this.text,
    required this.rising,
    this.improved,
  });

  final String text;
  final bool rising;

  /// Whether the change is good (true), bad (false) or has no verdict (null).
  final bool? improved;

  /// Null when [change] is missing or too small to matter.
  static DashboardDelta? from(
    double? change,
    String Function(double magnitude) format, {
    bool? lowerIsBetter,
    double threshold = 0.05,
  }) {
    if (change == null || change.abs() < threshold) return null;
    final rising = change > 0;
    return DashboardDelta(
      text: format(change.abs()),
      rising: rising,
      improved: lowerIsBetter == null ? null : rising != lowerIsBetter,
    );
  }
}
