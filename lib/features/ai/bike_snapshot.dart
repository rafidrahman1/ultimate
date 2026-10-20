import 'package:intl/intl.dart';

import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';

final _d = DateFormat('yyyy-MM-dd');

/// Everything the app knows about [bike] as plain text for an AI prompt:
/// profile, odometer, fuel, service, costs and papers. Capped so the prompt
/// stays small however long the history is.
String buildBikeSnapshot(MotoData data, Bike bike, DateTime today) {
  final m = data.currency;
  final b = StringBuffer();
  final odo = estimatedOdometer(data, bike, today);
  final rate = dailyRate(data, bike, today);

  b.writeln('TODAY: ${_d.format(today)}');
  b.writeln('BIKE: ${bike.fullName.isEmpty ? bike.name : bike.fullName}');
  if (bike.engineCc != null) b.writeln('Engine: ${bike.engineCc!.round()} cc');
  if (bike.usage.isNotEmpty) b.writeln('Usage: ${bike.usage}');
  if (bike.conditions.isNotEmpty) b.writeln('Conditions: ${bike.conditions}');
  b.writeln(
    'Added to the app ${_d.format(bike.addedOn)} at '
    '${bike.startOdometer.round()} km.',
  );
  b.writeln(
    'Odometer now (estimated): ${odo.round()} km; last logged: '
    '${latestOdometer(data, bike).round()} km.',
  );
  if (rate != null) {
    b.writeln(
      'Riding pace: ${rate.toStringAsFixed(1)} km/day '
      '(~${(rate * 30.4).round()} km/month, ~${(rate * 365).round()} km/year).',
    );
  }

  final fuel = [
    for (final f in data.fuel)
      if (f.bikeId == bike.id) f,
  ]..sort((a, b) => a.date.compareTo(b.date));
  final stats = fuelStats(fuel);
  b.writeln('\nFUEL ($m = currency symbol)');
  if (fuel.isEmpty) {
    b.writeln('No fill-ups logged.');
  } else {
    b.writeln(
      '${fuel.length} fill-ups, ${stats.totalLitres.toStringAsFixed(1)} L, '
      '$m${stats.totalCost.toStringAsFixed(0)} total.',
    );
    if (stats.averageKmPerLitre != null) {
      b.writeln(
        'Mileage: average ${stats.averageKmPerLitre!.toStringAsFixed(1)} km/l, '
        'best ${stats.bestKmPerLitre!.toStringAsFixed(1)}, '
        'last ${stats.lastKmPerLitre!.toStringAsFixed(1)}. '
        'Fuel cost per km: ${stats.costPerKm!.toStringAsFixed(2)}.',
      );
      b.writeln('Per-tank mileage (oldest first, km/l):');
      for (final s in stats.segments.skip(
        stats.segments.length > 20 ? stats.segments.length - 20 : 0,
      )) {
        b.writeln(
          '- ${_d.format(s.endDate)}: ${s.kmPerLitre.toStringAsFixed(1)} km/l '
          'over ${s.km.round()} km',
        );
      }
    }
    b.writeln('Recent fill-ups (date, odometer, litres, cost, price/L):');
    for (final f in fuel.skip(fuel.length > 12 ? fuel.length - 12 : 0)) {
      b.writeln(
        '- ${_d.format(f.date)}, ${f.odometer == null ? 'odometer unknown' : '${f.odometer!.round()} km'}, '
        '${f.litres.toStringAsFixed(2)} L, $m${f.cost.toStringAsFixed(0)}, '
        '${f.pricePerLitre.toStringAsFixed(1)}/L'
        '${f.fullTank ? '' : ' (partial)'}',
      );
    }
  }

  b.writeln('\nMAINTENANCE STATUS');
  for (final s in taskStatuses(data, bike, today)) {
    final parts = [
      if (s.task.intervalKm != null) 'every ${s.task.intervalKm!.round()} km',
      if (s.task.intervalDays != null) 'every ${s.task.intervalDays} days',
    ].join(' / ');
    final left = [
      if (s.kmLeft != null)
        s.kmLeft! < 0
            ? '${(-s.kmLeft!).round()} km overdue'
            : '${s.kmLeft!.round()} km left',
      if (s.daysLeft != null)
        s.daysLeft! < 0
            ? '${-s.daysLeft!} days overdue'
            : '${s.daysLeft} days left',
    ].join(', ');
    final last = s.neverDone
        ? 'never logged'
        : 'last ${_d.format(s.lastDate!)} at ${s.lastKm!.round()} km';
    b.writeln(
      '- ${s.task.name} ($parts): ${s.level.name}, $left; $last'
      '${s.task.note.isEmpty ? '' : ' [${s.task.note.replaceAll('\n', ' ')}]'}',
    );
  }

  final services = [
    for (final s in data.services)
      if (s.bikeId == bike.id) s,
  ]..sort((a, b) => a.date.compareTo(b.date));
  b.writeln('\nSERVICE HISTORY (${services.length} visits)');
  for (final s in services.skip(
    services.length > 15 ? services.length - 15 : 0,
  )) {
    b.writeln(
      '- ${_d.format(s.date)}, ${s.odometer == null ? 'odometer unknown' : '${s.odometer!.round()} km'}: ${s.title}, '
      '$m${s.cost.toStringAsFixed(0)}'
      '${s.notes.isEmpty ? '' : ' (${s.notes})'}',
    );
  }

  b.writeln('\nCOSTS');
  final all = costByCategory(data, bike);
  final km = latestOdometer(data, bike) - bike.startOdometer;
  b.writeln(
    'All time: $m${totalCost(all).toStringAsFixed(0)}'
    '${km > 50 ? ' ($m${(totalCost(all) / km).toStringAsFixed(2)} per km ridden since added)' : ''}.',
  );
  for (final e in all.entries) {
    b.writeln('- ${e.key}: $m${e.value.toStringAsFixed(0)}');
  }
  b.writeln('Monthly totals, last 12 months:');
  for (var i = 11; i >= 0; i--) {
    final from = DateTime(today.year, today.month - i);
    final to = DateTime(today.year, today.month - i + 1);
    final cats = costByCategory(data, bike, from: from, to: to);
    if (cats.isEmpty) continue;
    b.writeln(
      '- ${DateFormat('yyyy-MM').format(from)}: '
      '$m${totalCost(cats).toStringAsFixed(0)} '
      '(${cats.entries.map((e) => '${e.key} ${e.value.round()}').join(', ')})',
    );
  }

  final papers = [
    for (final p in data.papers)
      if (p.bikeId == bike.id) p,
  ]..sort((a, b) => a.expiry.compareTo(b.expiry));
  b.writeln('\nPAPERS');
  if (papers.isEmpty) b.writeln('None added.');
  for (final p in papers) {
    final left = paperDaysLeft(p, today);
    b.writeln(
      '- ${p.type.label}: expires ${_d.format(p.expiry)} '
      '(${left < 0 ? '${-left} days ago' : 'in $left days'})',
    );
  }
  return b.toString();
}
