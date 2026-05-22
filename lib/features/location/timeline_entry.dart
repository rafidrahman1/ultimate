import 'package:intl/intl.dart';

enum TimelineEntryKind { visit, activity }

class TimelineEntry {
  const TimelineEntry({
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.distanceMeters,
    this.activityType,
    this.visitType,
  });

  final TimelineEntryKind kind;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;
  final String? placeId;
  final double? distanceMeters;

  /// Raw Google Timeline type, e.g. MOTORCYCLING, WALKING.
  final String? activityType;

  /// Raw semantic type for visits, e.g. WORK, HOME.
  final String? visitType;

  Duration get duration => endTime.difference(startTime);
}

class TravelModeStat {
  const TravelModeStat({
    required this.mode,
    required this.label,
    required this.distanceMeters,
    required this.tripCount,
  });

  final String mode;
  final String label;
  final double distanceMeters;
  final int tripCount;

  double get distanceKm => distanceMeters / 1000;
}

class LocationHistorySummary {
  const LocationHistorySummary({
    required this.entries,
    this.fileName,
    this.forMonth,
  });

  final List<TimelineEntry> entries;
  final String? fileName;

  /// Anchor for which calendar month to summarize; defaults to now.
  final DateTime? forMonth;

  DateTime get monthAnchor => (forMonth ?? DateTime.now()).toLocal();

  String get monthLabel => DateFormat('MMMM yyyy').format(monthAnchor);

  List<TimelineEntry> get monthEntries => entries
      .where((e) => _isInMonth(e.startTime, monthAnchor))
      .toList();

  bool get hasMonthData => monthEntries.isNotEmpty;

  int get visitCount => monthEntries
      .where((e) => e.kind == TimelineEntryKind.visit)
      .length;

  int get activityCount => monthEntries
      .where((e) => e.kind == TimelineEntryKind.activity)
      .length;

  double get totalDistanceMeters => travelByMode.fold(
        0,
        (sum, stat) => sum + stat.distanceMeters,
      );

  double get totalDistanceKm => totalDistanceMeters / 1000;

  List<TimelineEntry> get sortedByTime =>
      List<TimelineEntry>.from(monthEntries)
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  List<TravelModeStat> get travelByMode {
    final meters = <String, double>{};
    final trips = <String, int>{};

    for (final entry in monthEntries) {
      if (entry.kind != TimelineEntryKind.activity) continue;
      final mode = entry.activityType;
      final distance = entry.distanceMeters;
      if (mode == null || distance == null || distance <= 0) continue;
      meters[mode] = (meters[mode] ?? 0) + distance;
      trips[mode] = (trips[mode] ?? 0) + 1;
    }

    return meters.entries
        .map(
          (e) => TravelModeStat(
            mode: e.key,
            label: formatTimelineLabel(e.key),
            distanceMeters: e.value,
            tripCount: trips[e.key] ?? 0,
          ),
        )
        .toList()
      ..sort((a, b) => b.distanceMeters.compareTo(a.distanceMeters));
  }

  Map<String, int> get visitsByType {
    final counts = <String, int>{};
    for (final entry in monthEntries) {
      if (entry.kind != TimelineEntryKind.visit) continue;
      final type = entry.visitType ?? 'UNKNOWN';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  DateTime? get periodStart {
    if (monthEntries.isEmpty) return null;
    return monthEntries
        .map((e) => e.startTime)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get periodEnd {
    if (monthEntries.isEmpty) return null;
    return monthEntries
        .map((e) => e.endTime)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Human-readable range, e.g. "16 Apr 2026 – 14 May 2026".
  String? get periodRangeLabel {
    final start = periodStart;
    final end = periodEnd;
    if (start == null || end == null) return null;
    final dateFormat = DateFormat('d MMM yyyy');
    final startLabel = dateFormat.format(start.toLocal());
    final endLabel = dateFormat.format(end.toLocal());
    if (startLabel == endLabel) return startLabel;
    return '$startLabel – $endLabel';
  }

  int? get periodDays {
    final start = periodStart;
    final end = periodEnd;
    if (start == null || end == null) return null;
    return end.difference(start).inDays + 1;
  }

  String toAiSummary() {
    final buffer = StringBuffer(
      'Location & travel summary — $monthLabel (Google Timeline)\n',
    );
    if (fileName != null) buffer.writeln('Source: $fileName');

    final range = periodRangeLabel;
    if (range != null) {
      final days = periodDays;
      buffer.writeln(
        days != null ? 'Dates in month: $range ($days days)' : 'Dates in month: $range',
      );
    }

    buffer.writeln(
      'Total tracked travel: ${totalDistanceKm.toStringAsFixed(1)} km '
      '($activityCount trips)',
    );
    buffer.writeln();

    final modes = travelByMode;
    if (modes.isNotEmpty) {
      buffer.writeln('Distance by travel mode:');
      for (final stat in modes) {
        buffer.writeln(
          '- ${stat.label}: ${stat.distanceKm.toStringAsFixed(1)} km '
          '(${stat.tripCount} trips)',
        );
      }
      buffer.writeln();
    }

    final visits = visitsByType;
    if (visits.isNotEmpty) {
      buffer.writeln('Place visits ($visitCount total):');
      final sorted = visits.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in sorted) {
        buffer.writeln(
          '- ${formatTimelineLabel(entry.key)}: ${entry.value}',
        );
      }
    }

    return buffer.toString().trim();
  }
}

bool _isInMonth(DateTime time, DateTime month) {
  final local = time.toLocal();
  return local.year == month.year && local.month == month.month;
}

String formatTimelineLabel(String raw) {
  return raw
      .toLowerCase()
      .split('_')
      .map((part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}