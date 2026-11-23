import 'dart:math' as math;

/// Travel modes, using Google Timeline's names so recorded trips and
/// imported ones mean the same thing.
abstract final class TravelModes {
  static const walking = 'WALKING';
  static const running = 'RUNNING';
  static const cycling = 'CYCLING';
  static const motorcycling = 'MOTORCYCLING';
  static const car = 'IN_PASSENGER_VEHICLE';
  static const taxi = 'IN_TAXI';
  static const bus = 'IN_BUS';
  static const train = 'IN_TRAIN';
  static const subway = 'IN_SUBWAY';
  static const boat = 'BOATING';
  static const flying = 'FLYING';

  /// Every mode you can pick when correcting a trip, in menu order.
  static const all = [
    motorcycling,
    walking,
    car,
    bus,
    taxi,
    cycling,
    running,
    train,
    subway,
    boat,
    flying,
  ];

  static String label(String type) => switch (type.toUpperCase()) {
    walking => 'Walking',
    running => 'Running',
    cycling => 'Cycling',
    motorcycling => 'Motorcycle',
    car => 'Car',
    taxi => 'Taxi / ride share',
    bus => 'Bus',
    train => 'Train',
    subway => 'Metro',
    boat => 'Boat',
    flying => 'Flight',
    _ => 'Moving',
  };
}

/// One trip whose mode is known, as training data.
class LabelledTrip {
  const LabelledTrip({
    required this.type,
    required this.avgKmh,
    this.weight = 1,
  });

  final String type;
  final double avgKmh;

  /// Your own corrections count more than Google's guesses.
  final double weight;
}

/// Picks a travel mode from how fast a trip went and what Android sensed.
///
/// Android only knows "vehicle" vs "bicycle" vs "on foot", so the model
/// learns your typical speed for each mode (log-normal) and how often you use
/// it, from your Google history and every trip you correct.
class TravelModeClassifier {
  TravelModeClassifier._(this._stats, this._total);

  factory TravelModeClassifier.train(Iterable<LabelledTrip> trips) {
    final acc = <String, _Acc>{};
    for (final trip in trips) {
      if (trip.avgKmh <= 0.3 || trip.avgKmh > 1000) continue;
      final type = trip.type.toUpperCase();
      if (!TravelModes.all.contains(type)) continue;
      acc.putIfAbsent(type, _Acc.new).add(math.log(trip.avgKmh), trip.weight);
    }
    final stats = <String, _ModeStats>{};
    for (final type in TravelModes.all) {
      final prior = _defaults[type]!;
      final a = acc[type];
      // Blend learned figures with sensible defaults so a mode seen twice
      // doesn't get an absurd spread.
      const priorWeight = 3.0;
      final w = a?.weight ?? 0;
      final mean = a == null
          ? math.log(prior.kmh)
          : (a.sum + math.log(prior.kmh) * priorWeight) / (w + priorWeight);
      final variance = a == null || w < 2
          ? prior.spread * prior.spread
          : math.max((a.sumSq / w - math.pow(a.sum / w, 2)).toDouble(), 0.04);
      stats[type] = _ModeStats(
        mean: mean,
        sd: math.sqrt(variance),
        count: w + prior.baseCount,
      );
    }
    final total = stats.values.fold<double>(0, (s, m) => s + m.count);
    return TravelModeClassifier._(stats, total);
  }

  final Map<String, _ModeStats> _stats;
  final double _total;

  /// The most likely mode for a trip averaging [avgKmh] door to door.
  /// [activity] is Android's IN_VEHICLE / ON_BICYCLE / WALKING / RUNNING.
  String classify({required double avgKmh, String? activity}) {
    if (avgKmh > 200) return TravelModes.flying;
    final candidates = _candidatesFor(activity, avgKmh);
    String? best;
    var bestScore = double.negativeInfinity;
    final x = math.log(math.max(avgKmh, 0.5));
    for (final type in candidates) {
      final s = _stats[type]!;
      final z = (x - s.mean) / s.sd;
      final score = math.log(s.count / _total) - math.log(s.sd) - z * z / 2;
      if (score > bestScore) {
        bestScore = score;
        best = type;
      }
    }
    return best ?? TravelModes.walking;
  }

  List<String> _candidatesFor(String? activity, double avgKmh) {
    switch (activity) {
      case 'WALKING':
        // Android says walking but it was too fast: don't trust it.
        if (avgKmh < 9) return const [TravelModes.walking];
      case 'RUNNING':
        if (avgKmh < 20) return const [TravelModes.running];
      case 'ON_BICYCLE':
        // Motorbikes are often sensed as bicycles.
        return const [TravelModes.cycling, TravelModes.motorcycling];
      case 'IN_VEHICLE':
        return const [
          TravelModes.motorcycling,
          TravelModes.car,
          TravelModes.taxi,
          TravelModes.bus,
          TravelModes.train,
          TravelModes.subway,
          TravelModes.boat,
        ];
    }
    return [
      for (final type in TravelModes.all)
        if (type != TravelModes.flying) type,
    ];
  }
}

class _Acc {
  double sum = 0;
  double sumSq = 0;
  double weight = 0;

  void add(double x, double w) {
    sum += x * w;
    sumSq += x * x * w;
    weight += w;
  }
}

class _ModeStats {
  const _ModeStats({required this.mean, required this.sd, required this.count});

  final double mean;
  final double sd;
  final double count;
}

class _Default {
  const _Default(this.kmh, this.spread, this.baseCount);

  final double kmh;

  /// Standard deviation of log speed.
  final double spread;

  /// How likely this mode is before any history.
  final double baseCount;
}

const _defaults = <String, _Default>{
  TravelModes.walking: _Default(4.5, 0.35, 3),
  TravelModes.running: _Default(9, 0.3, 0.3),
  TravelModes.cycling: _Default(13, 0.35, 0.5),
  TravelModes.motorcycling: _Default(22, 0.45, 2),
  TravelModes.car: _Default(22, 0.5, 2),
  TravelModes.taxi: _Default(20, 0.5, 0.5),
  TravelModes.bus: _Default(14, 0.5, 1),
  TravelModes.train: _Default(45, 0.5, 0.3),
  TravelModes.subway: _Default(35, 0.4, 0.3),
  TravelModes.boat: _Default(12, 0.6, 0.2),
  TravelModes.flying: _Default(500, 0.5, 0.1),
};
