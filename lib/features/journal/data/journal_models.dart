/// Hour at which a new "habit day" starts. A coffee or a check-in at 01:00
/// still belongs to the evening before.
const habitDayStartHour = 4;

/// The local day [at] counts towards, with the day turning over at
/// [habitDayStartHour] instead of midnight.
DateTime habitDayOf(DateTime at) {
  final l = at.toLocal().subtract(const Duration(hours: habitDayStartHour));
  return DateTime(l.year, l.month, l.day);
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// How one day felt, each on a 1 (low) to 5 (high) scale.
class DayCheckIn {
  const DayCheckIn({
    required this.day,
    required this.mood,
    required this.energy,
    required this.stress,
  });

  final DateTime day;
  final int mood;
  final int energy;
  final int stress;

  Map<String, dynamic> toJson() => {
    'd': _dayKey(day),
    'm': mood,
    'e': energy,
    's': stress,
  };

  static DayCheckIn? fromJson(Map<String, dynamic> j) {
    final day = DateTime.tryParse(j['d'] as String? ?? '');
    final m = j['m'];
    final e = j['e'];
    final s = j['s'];
    if (day == null || m is! int || e is! int || s is! int) return null;
    bool ok(int v) => v >= 1 && v <= 5;
    if (!ok(m) || !ok(e) || !ok(s)) return null;
    return DayCheckIn(
      day: DateTime(day.year, day.month, day.day),
      mood: m,
      energy: e,
      stress: s,
    );
  }
}

enum IntakeKind {
  caffeine('Coffee', 'coffee'),
  meal('Meal', 'meal');

  const IntakeKind(this.label, this.noun);

  final String label;
  final String noun;

  static IntakeKind? byName(String? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// A coffee (or other caffeine) or a meal, at the time it was had.
class IntakeEvent {
  const IntakeEvent(this.at, this.kind);

  final DateTime at;
  final IntakeKind kind;

  Map<String, dynamic> toJson() => {
    't': at.millisecondsSinceEpoch,
    'k': kind.name,
  };

  static IntakeEvent? fromJson(Map<String, dynamic> j) {
    final t = j['t'];
    final kind = IntakeKind.byName(j['k'] as String?);
    if (t is! int || kind == null) return null;
    return IntakeEvent(DateTime.fromMillisecondsSinceEpoch(t), kind);
  }
}

/// Everything logged by hand: daily check-ins, coffees and meals.
class Journal {
  Journal({
    List<DayCheckIn> checkIns = const [],
    List<IntakeEvent> intakes = const [],
  }) : checkIns = [...checkIns]..sort((a, b) => a.day.compareTo(b.day)),
       intakes = [...intakes]..sort((a, b) => a.at.compareTo(b.at));

  static final empty = Journal();

  /// Oldest first, one per day.
  final List<DayCheckIn> checkIns;

  /// Oldest first.
  final List<IntakeEvent> intakes;

  bool get isEmpty => checkIns.isEmpty && intakes.isEmpty;

  DayCheckIn? checkInOn(DateTime day) {
    for (final c in checkIns) {
      if (c.day == day) return c;
    }
    return null;
  }

  List<IntakeEvent> intakesOn(DateTime habitDay) => [
    for (final e in intakes)
      if (habitDayOf(e.at) == habitDay) e,
  ];

  /// How many [kind] entries each habit day has.
  Map<DateTime, int> countByDay(IntakeKind kind) {
    final out = <DateTime, int>{};
    for (final e in intakes) {
      if (e.kind != kind) continue;
      final d = habitDayOf(e.at);
      out[d] = (out[d] ?? 0) + 1;
    }
    return out;
  }

  /// The last [kind] entry of each habit day, in minutes after that day's
  /// midnight. Past midnight it runs above 1440 (01:00 is 1500).
  Map<DateTime, int> lastMinutesByDay(IntakeKind kind) {
    final out = <DateTime, int>{};
    for (final e in intakes) {
      if (e.kind != kind) continue;
      final d = habitDayOf(e.at);
      final minutes = e.at.toLocal().difference(d).inMinutes;
      final prev = out[d];
      if (prev == null || minutes > prev) out[d] = minutes;
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'checkIns': [for (final c in checkIns) c.toJson()],
    'intakes': [for (final e in intakes) e.toJson()],
  };

  factory Journal.fromJson(Map<String, dynamic> j) {
    Iterable<Map<String, dynamic>> rows(Object? v) => v is List
        ? v.whereType<Map<dynamic, dynamic>>().map(
            (m) => m.cast<String, dynamic>(),
          )
        : const [];
    return Journal(
      checkIns: [for (final r in rows(j['checkIns'])) ?DayCheckIn.fromJson(r)],
      intakes: [for (final r in rows(j['intakes'])) ?IntakeEvent.fromJson(r)],
    );
  }
}
