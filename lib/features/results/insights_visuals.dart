part of 'insights_dashboard.dart';

class _AnomalyVisual {
  const _AnomalyVisual({
    required this.icon,
    required this.accent,
    required this.borderColor,
  });

  final IconData icon;
  final Color accent;
  final Color borderColor;

  factory _AnomalyVisual.forAnomaly(
    InsightAnomaly anomaly,
    AppPalette palette,
  ) {
    final text = '${anomaly.title} ${anomaly.description}'.toLowerCase();

    if (_containsAny(text, const [
      'financial',
      'hemorrhage',
      'expense',
      'spending',
      'discretionary',
      'salary',
      'runway',
      'gift',
    ])) {
      final alert = text.contains('hemorrhage') || text.contains('critically');
      return _AnomalyVisual(
        icon: alert
            ? Icons.warning_amber_rounded
            : Icons.account_balance_wallet_rounded,
        accent: palette.expenses,
        borderColor: palette.border,
      );
    }

    if (_containsAny(text, const [
      'vespa',
      'fuel',
      'economy',
      'mileage',
      'carburetor',
      'transport',
      'mobility',
      'motorcycle',
      'location',
    ])) {
      return _AnomalyVisual(
        icon: text.contains('fuel') || text.contains('octane')
            ? Icons.local_gas_station_rounded
            : Icons.moped_rounded,
        accent: palette.mobility,
        borderColor: palette.border,
      );
    }

    if (_containsAny(text, const [
      'sleep',
      'cardiovascular',
      'neat',
      'steps',
      'heart',
    ])) {
      final useBed = text.contains('sleep') || text.contains('bedtime');
      return _AnomalyVisual(
        icon: useBed ? Icons.bedtime_rounded : Icons.favorite_rounded,
        accent: useBed ? palette.warning : palette.health,
        borderColor: palette.border,
      );
    }

    return _AnomalyVisual(
      icon: Icons.insights_rounded,
      accent: palette.accent,
      borderColor: palette.border,
    );
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}

class _ActionVisual {
  const _ActionVisual({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  factory _ActionVisual.forCategory(
    InsightItemCategory category,
    AppPalette palette,
  ) {
    return switch (category) {
      InsightItemCategory.health => _ActionVisual(
        icon: Icons.bedtime_rounded,
        accent: palette.health,
      ),
      InsightItemCategory.expenses => _ActionVisual(
        icon: Icons.account_balance_wallet_rounded,
        accent: palette.expenses,
      ),
      InsightItemCategory.transport => _ActionVisual(
        icon: Icons.moped_rounded,
        accent: palette.mobility,
      ),
      InsightItemCategory.gaming => _ActionVisual(
        icon: Icons.sports_esports_rounded,
        accent: palette.gameActivity,
      ),
      InsightItemCategory.calendar => _ActionVisual(
        icon: Icons.calendar_month_rounded,
        accent: palette.accent,
      ),
      InsightItemCategory.general => _ActionVisual(
        icon: Icons.task_alt_rounded,
        accent: palette.accent,
      ),
    };
  }
}

List<String> _extractHighlights(String text) {
  final highlights = <String>[];
  final seen = <String>{};
  for (final match in RegExp(r'\*\*([^*]+)\*\*').allMatches(text)) {
    final value = match.group(1)?.trim() ?? '';
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.contains(key)) continue;
    if (!RegExp(r'\d').hasMatch(value)) continue;
    seen.add(key);
    highlights.add(value);
  }
  return highlights;
}
