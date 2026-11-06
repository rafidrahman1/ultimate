import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/screen_time/data/screen_time_models.dart';

void main() {
  test('parses channel rows and groups by day and app', () {
    final d1 = DateTime(2026, 11, 1).millisecondsSinceEpoch;
    final d2 = DateTime(2026, 11, 2).millisecondsSinceEpoch;
    final summary = ScreenTimeSummary.fromChannelRows([
      {'day': d1, 'package': 'a', 'label': 'A', 'ms': 60 * 60000},
      {'day': d1, 'package': 'b', 'label': 'B', 'ms': 30 * 60000},
      {'day': d2, 'package': 'a', 'label': 'A', 'ms': 30 * 60000},
      {'bad': 1},
    ]);
    expect(summary.total, const Duration(minutes: 120));
    expect(summary.byDay.length, 2);
    expect(summary.averagePerActiveDay, const Duration(minutes: 60));
    expect(summary.topApps.first.packageName, 'a');
    expect(summary.topApps.first.duration, const Duration(minutes: 90));
  });
}
