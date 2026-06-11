/// Domain bucket for anomalies and action directives.
enum InsightItemCategory {
  health,
  expenses,
  transport,
  gaming,
  calendar,
  general;

  String get label => switch (this) {
    InsightItemCategory.health => 'Health',
    InsightItemCategory.expenses => 'Expenses',
    InsightItemCategory.transport => 'Transport',
    InsightItemCategory.gaming => 'Gaming',
    InsightItemCategory.calendar => 'Calendar',
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
    if (_containsAny(lower, const [
      'gaming',
      'game',
      'steam',
      'screen time',
      'screen-time',
      'leisure',
      'playtime',
      'play time',
    ])) {
      return InsightItemCategory.gaming;
    }
    if (_containsAny(lower, const [
      'calendar',
      'schedule',
      'holiday',
      'event',
      'workday',
    ])) {
      return InsightItemCategory.calendar;
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
    if (lower.contains('gaming') ||
        lower.contains('leisure') ||
        lower.contains('screen time') ||
        lower.contains('screen-time')) {
      return InsightItemCategory.gaming;
    }
    if (lower.contains('calendar') || lower.contains('schedule')) {
      return InsightItemCategory.calendar;
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
    this.theme,
  });

  final String title;
  final List<ActionDirective> actions;
  final int? weekNumber;

  /// Weekly theme from AI output (Recovery, Stabilization, etc.).
  final String? theme;
}

/// Container returned by [InsightsReportParser.parse].
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
    if (index < 0) return const [];
    final targetWeekNumber = index + 1;
    for (final week in weeks) {
      if (week.weekNumber == targetWeekNumber) return week.actions;
    }
    if (index >= weeks.length) return const [];
    return weeks[index].actions;
  }

  /// Theme for checklist week [index], when present in parsed output.
  String? themeForWeekIndex(int index) {
    if (index < 0) return null;
    final targetWeekNumber = index + 1;
    for (final week in weeks) {
      if (week.weekNumber == targetWeekNumber) return week.theme;
    }
    if (index >= weeks.length) return null;
    return weeks[index].theme;
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
      InsightItemCategory.gaming,
      InsightItemCategory.calendar,
      InsightItemCategory.general,
    ];
    return order.where(seen.contains);
  }
}
