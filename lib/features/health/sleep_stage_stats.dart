import 'package:personal/features/health/health_summary.dart';

/// Averages of sleep stages over the nights that recorded them.
class SleepStageStats {
  const SleepStageStats({
    required this.nights,
    required this.avgDeep,
    required this.avgLight,
    required this.avgRem,
    required this.avgAwake,
    required this.avgAwakeEpisodes,
    this.avgEfficiency,
  });

  /// Nights with stage data.
  final int nights;
  final Duration avgDeep;
  final Duration avgLight;
  final Duration avgRem;
  final Duration avgAwake;
  final double avgAwakeEpisodes;

  /// Null if no night recorded awake time.
  final double? avgEfficiency;

  Duration get avgAsleep => avgDeep + avgLight + avgRem;

  double get deepShare =>
      avgAsleep == Duration.zero ? 0 : avgDeep.inSeconds / avgAsleep.inSeconds;
  double get remShare =>
      avgAsleep == Duration.zero ? 0 : avgRem.inSeconds / avgAsleep.inSeconds;
  double get lightShare =>
      avgAsleep == Duration.zero ? 0 : avgLight.inSeconds / avgAsleep.inSeconds;
}

/// Fewer staged nights than this and an average says little.
const minStagedNights = 3;

SleepStageStats? computeSleepStageStats(List<DailySleepEntry> nights) {
  final staged = [
    for (final n in nights)
      if (n.session?.stages != null) n.session!.stages!,
  ];
  if (staged.length < minStagedNights) return null;

  Duration mean(Duration Function(SleepStages) pick) => Duration(
    seconds:
        staged.fold<int>(0, (sum, s) => sum + pick(s).inSeconds) ~/
        staged.length,
  );

  final efficiencies = [
    for (final s in staged)
      if (s.efficiency != null) s.efficiency!,
  ];

  return SleepStageStats(
    nights: staged.length,
    avgDeep: mean((s) => s.deep),
    avgLight: mean((s) => s.light),
    avgRem: mean((s) => s.rem),
    avgAwake: mean((s) => s.awake),
    avgAwakeEpisodes:
        staged.fold<int>(0, (sum, s) => sum + s.awakeEpisodes) / staged.length,
    avgEfficiency: efficiencies.isEmpty
        ? null
        : efficiencies.fold<double>(0, (sum, e) => sum + e) /
              efficiencies.length,
  );
}
