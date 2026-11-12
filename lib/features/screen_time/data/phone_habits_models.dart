/// How the phone was picked up on one phone day (04:00 to 04:00).
class PhoneDay {
  const PhoneDay({
    required this.day,
    required this.pickups,
    this.firstUse,
    this.lastUse,
    this.complete = true,
  });

  /// Local midnight of the day the phone day starts on.
  final DateTime day;

  /// Unlocks (screen-ons on a phone with no lock screen).
  final int pickups;
  final DateTime? firstUse;

  /// When the screen last went off after being used.
  final DateTime? lastUse;

  /// False while the phone day is still running, so [lastUse] is not final.
  final bool complete;

  /// [firstUse] in minutes after [day]'s midnight.
  int? get firstUseMinutes => firstUse?.difference(day).inMinutes;

  /// [lastUse] in minutes after [day]'s midnight. Past midnight it runs above
  /// 1440 (01:00 is 1500).
  int? get lastUseMinutes => lastUse?.difference(day).inMinutes;

  Map<String, dynamic> toJson() => {
    'day': day.millisecondsSinceEpoch,
    'pickups': pickups,
    'firstMs': firstUse?.millisecondsSinceEpoch,
    'lastMs': lastUse?.millisecondsSinceEpoch,
    'complete': complete,
  };

  /// Reads a row from the usage channel or the cache; null when malformed.
  static PhoneDay? fromRow(Map<dynamic, dynamic> row) {
    final day = row['day'];
    final pickups = row['pickups'];
    if (day is! num || pickups is! num || pickups <= 0) return null;
    DateTime? at(Object? ms) => ms is num && ms > 0
        ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
        : null;
    final d = DateTime.fromMillisecondsSinceEpoch(day.toInt());
    return PhoneDay(
      day: DateTime(d.year, d.month, d.day),
      pickups: pickups.toInt(),
      firstUse: at(row['firstMs']),
      lastUse: at(row['lastMs']),
      complete: row['complete'] != false,
    );
  }
}

/// Pickups and first/last use per day, oldest first.
class PhoneHabits {
  PhoneHabits(Iterable<PhoneDay> days)
    : days = [...days]..sort((a, b) => a.day.compareTo(b.day));

  static final empty = PhoneHabits(const []);

  final List<PhoneDay> days;

  bool get isEmpty => days.isEmpty;

  PhoneDay? on(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    for (final d in days) {
      if (d.day == key) return d;
    }
    return null;
  }

  /// Days that have ended, so every figure on them is final.
  List<PhoneDay> get completeDays => [
    for (final d in days)
      if (d.complete) d,
  ];

  /// Android only keeps a few days of the events these come from, so days
  /// already saved are kept. A fresh read wins unless it lost events since
  /// (fewer pickups on a day that had already ended).
  PhoneHabits mergedWith(PhoneHabits fresh) {
    final byDay = {for (final d in days) d.day: d};
    for (final f in fresh.days) {
      final old = byDay[f.day];
      if (old == null || !old.complete || f.pickups >= old.pickups) {
        byDay[f.day] = f;
      }
    }
    return PhoneHabits(byDay.values);
  }

  /// Drops days before [cutoff].
  PhoneHabits since(DateTime cutoff) =>
      PhoneHabits(days.where((d) => !d.day.isBefore(cutoff)));

  Map<String, dynamic> toJson() => {
    'days': [for (final d in days) d.toJson()],
  };

  static PhoneHabits fromRows(Iterable<Object?> rows) => PhoneHabits([
    for (final r in rows)
      if (r is Map) ?PhoneDay.fromRow(r),
  ]);

  factory PhoneHabits.fromJson(Map<String, dynamic> json) {
    final rows = json['days'];
    return rows is List ? fromRows(rows) : empty;
  }
}
