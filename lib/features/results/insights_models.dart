/// Domain bucket for anomalies.
enum InsightItemCategory {
  health,
  expenses,
  transport,
  general;

  String get label => switch (this) {
    InsightItemCategory.health => 'Health',
    InsightItemCategory.expenses => 'Expenses',
    InsightItemCategory.transport => 'Transport',
    InsightItemCategory.general => 'General',
  };

  static InsightItemCategory fromKeywords(String text) {
    final lower = text.toLowerCase();
    if (_containsAny(lower, const [
      'sleep',
      'cardiovascular',
      'neat',
      'heart',
      'bpm',
      'cortisol',
      'snack',
      'calorie',
      'physique',
      'abs',
      'bedtime',
    ])) {
      return InsightItemCategory.health;
    }
    if (_containsAny(lower, const [
      'financial',
      'hemorrhage',
      'expense',
      'spending',
      'discretionary',
      'budget',
      'bdt',
      'salary',
      'gift',
      'cashew',
      'electronics',
      'income',
      'runway',
    ])) {
      return InsightItemCategory.expenses;
    }
    if (_containsAny(lower, const [
      'vespa',
      'fuel',
      'economy',
      'transport',
      'mobility',
      'motorcycle',
      'location',
      'mileage',
      'carburetor',
      'moped',
      'odometer',
      'mechanic',
      'commute',
    ])) {
      return InsightItemCategory.transport;
    }
    return InsightItemCategory.general;
  }

  /// Prefer the anomaly title so body text (e.g. "fuel expenses") does not override.
  static InsightItemCategory categorizeAnomaly(String title, String description) {
    final fromTitle = fromGroupHeader(title);
    if (fromTitle != InsightItemCategory.general) return fromTitle;
    final fromTitleKeywords = fromKeywords(title);
    if (fromTitleKeywords != InsightItemCategory.general) {
      return fromTitleKeywords;
    }
    return fromKeywords('$title $description');
  }

  static InsightItemCategory fromGroupHeader(String header) {
    final lower = header.toLowerCase();
    if (lower.contains('health') || lower.contains('sleep')) {
      return InsightItemCategory.health;
    }
    if (lower.contains('expense') ||
        lower.contains('cashew') ||
        lower.contains('budget')) {
      return InsightItemCategory.expenses;
    }
    if (lower.contains('transport') ||
        lower.contains('logistic') ||
        lower.contains('mobility') ||
        lower.contains('location')) {
      return InsightItemCategory.transport;
    }
    if (lower.contains('calendar') || lower.contains('schedule')) {
      return InsightItemCategory.general;
    }
    return fromKeywords(header);
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

/// Parsed AI insight: pattern / anomaly bullet.
class InsightAnomaly {
  const InsightAnomaly({
    required this.title,
    required this.description,
    required this.category,
  });

  final String title;
  final String description;

  /// Display category: Health, Expenses, Transport, or General.
  final String category;

  InsightItemCategory get categoryEnum => InsightItemCategory.values.firstWhere(
    (c) => c.label == category,
    orElse: () => InsightItemCategory.general,
  );
}

/// Container returned by [InsightsReportParser.parse].
class InsightsParsedReport {
  const InsightsParsedReport({
    this.anomalies = const [],
  });

  final List<InsightAnomaly> anomalies;

  bool get isEmpty => anomalies.isEmpty;
}
