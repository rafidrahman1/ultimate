part of 'place_stats.dart';

/// One calendar month of travel, for trend charts.
class MonthlyLocationRow {
  const MonthlyLocationRow({
    required this.month,
    required this.motorcycleKm,
    required this.totalKm,
    required this.rides,
    required this.workDays,
  });

  final DateTime month;
  final double motorcycleKm;
  final double totalKm;
  final int rides;
  final int workDays;
}

/// Every month from the first to the last segment, oldest first, including
/// months with no data (as zeros) so a chart's x-axis stays continuous.
List<MonthlyLocationRow> buildMonthlyHistory(LocationSummary summary) {
  final motoKm = <int, double>{};
  final totalKm = <int, double>{};
  final rides = <int, int>{};
  final workDays = <int, Set<int>>{};

  int key(DateTime d) => d.year * 12 + (d.month - 1);

  for (final a in summary.activities) {
    final local = a.startTime.toLocal();
    final k = key(local);
    totalKm[k] = (totalKm[k] ?? 0) + a.distanceMeters / 1000;
    if (a.isMotorcycling) {
      motoKm[k] = (motoKm[k] ?? 0) + a.distanceMeters / 1000;
      rides[k] = (rides[k] ?? 0) + 1;
    }
  }
  for (final v in summary.placeVisits) {
    if (v.isNested || !(v.isWork)) continue;
    final local = v.startTime.toLocal();
    workDays.putIfAbsent(key(local), () => {}).add(local.day);
  }

  final keys = {...totalKm.keys, ...workDays.keys};
  if (keys.isEmpty) return const [];
  final first = keys.reduce((a, b) => a < b ? a : b);
  final last = keys.reduce((a, b) => a > b ? a : b);

  return [
    for (var k = first; k <= last; k++)
      MonthlyLocationRow(
        month: DateTime(k ~/ 12, k % 12 + 1),
        motorcycleKm: motoKm[k] ?? 0,
        totalKm: totalKm[k] ?? 0,
        rides: rides[k] ?? 0,
        workDays: workDays[k]?.length ?? 0,
      ),
  ];
}
