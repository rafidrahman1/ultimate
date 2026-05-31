/// Domain bucket for anomalies and action directives.
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
      'steps',
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
      'mileage',
      'carburetor',
      'moped',
      'odometer',
      'mechanic',
    ])) {
      return InsightItemCategory.transport;
    }
    return InsightItemCategory.general;
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
    if (lower.contains('transport') || lower.contains('logistic')) {
      return InsightItemCategory.transport;
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

/// Parsed AI insight: next-7-days action bullet.
class ActionDirective {
  const ActionDirective({
    required this.title,
    required this.description,
    required this.category,
    this.groupLabel,
  });

  final String title;
  final String description;

  /// Display category: Health, Expenses, Transport, or General.
  final String category;

  /// Raw #### subsection title (e.g. "Health & Sleep").
  final String? groupLabel;

  InsightItemCategory get categoryEnum => InsightItemCategory.values.firstWhere(
    (c) => c.label == category,
    orElse: () => InsightItemCategory.general,
  );
}

/// One week of the monthly checklist (from ##### week headers in AI output).
class InsightChecklistWeek {
  const InsightChecklistWeek({
    required this.title,
    required this.actions,
    this.weekNumber,
  });

  final String title;
  final List<ActionDirective> actions;
  final int? weekNumber;
}

/// Container returned by [InsightParser.parse].
class InsightsParsedReport {
  const InsightsParsedReport({
    this.anomalies = const [],
    this.actions = const [],
    this.weeks = const [],
  });

  final List<InsightAnomaly> anomalies;
  final List<ActionDirective> actions;
  final List<InsightChecklistWeek> weeks;

  bool get isEmpty => anomalies.isEmpty && actions.isEmpty;

  int get checklistWeekCount =>
      weeks.isEmpty ? (actions.isEmpty ? 0 : 1) : weeks.length;

  List<ActionDirective> actionsForWeekIndex(int index) {
    if (weeks.isEmpty) return actions;
    if (index < 0 || index >= weeks.length) return const [];
    return weeks[index].actions;
  }

  List<ActionDirective> actionsFor(InsightItemCategory category) {
    return actions.where((a) => a.categoryEnum == category).toList();
  }

  Iterable<InsightItemCategory> get actionCategories {
    final seen = <InsightItemCategory>{};
    for (final action in actions) {
      seen.add(action.categoryEnum);
    }
    const order = [
      InsightItemCategory.health,
      InsightItemCategory.expenses,
      InsightItemCategory.transport,
      InsightItemCategory.general,
    ];
    return order.where(seen.contains);
  }
}
