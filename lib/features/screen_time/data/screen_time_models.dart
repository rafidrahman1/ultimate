/// One app's foreground time on one local day.
class AppUsageEntry {
  const AppUsageEntry({
    required this.day,
    required this.packageName,
    required this.label,
    required this.duration,
  });

  final DateTime day;
  final String packageName;
  final String label;
  final Duration duration;
}

class AppUsageTotal {
  const AppUsageTotal(this.packageName, this.label, this.duration);

  final String packageName;
  final String label;
  final Duration duration;
}

/// Screen time for a stretch of days, grouped by day and by app.
class ScreenTimeSummary {
  const ScreenTimeSummary(this.entries);

  static const empty = ScreenTimeSummary([]);

  final List<AppUsageEntry> entries;

  bool get isEmpty => entries.isEmpty;

  Duration get total =>
      entries.fold(Duration.zero, (sum, e) => sum + e.duration);

  /// Total per local calendar day (only days with usage).
  Map<DateTime, Duration> get byDay {
    final out = <DateTime, Duration>{};
    for (final e in entries) {
      final key = DateTime(e.day.year, e.day.month, e.day.day);
      out[key] = (out[key] ?? Duration.zero) + e.duration;
    }
    return out;
  }

  Duration get averagePerActiveDay {
    final days = byDay;
    if (days.isEmpty) return Duration.zero;
    return Duration(minutes: (total.inMinutes / days.length).round());
  }

  /// Apps ordered by total time, longest first.
  List<AppUsageTotal> get topApps {
    final minutes = <String, Duration>{};
    final labels = <String, String>{};
    for (final e in entries) {
      minutes[e.packageName] =
          (minutes[e.packageName] ?? Duration.zero) + e.duration;
      labels[e.packageName] = e.label;
    }
    return [
      for (final p in minutes.entries)
        AppUsageTotal(p.key, labels[p.key] ?? p.key, p.value),
    ]..sort((a, b) => b.duration.compareTo(a.duration));
  }

  static ScreenTimeSummary fromChannelRows(List<Object?> rows) {
    final entries = <AppUsageEntry>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final day = row['day'];
      final ms = row['ms'];
      final pkg = row['package'];
      if (day is! num || ms is! num || pkg is! String) continue;
      entries.add(
        AppUsageEntry(
          day: DateTime.fromMillisecondsSinceEpoch(day.toInt()),
          packageName: pkg,
          label: (row['label'] as String?) ?? pkg,
          duration: Duration(milliseconds: ms.toInt()),
        ),
      );
    }
    return ScreenTimeSummary(entries);
  }
}
