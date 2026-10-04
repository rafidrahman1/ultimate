import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/home/home_tile_stats.dart';

void main() {
  group('dailySeries', () {
    final past = DateTime(2024, 2); // leap February, long finished

    test('buckets values by day across the whole past month', () {
      final series = dailySeries([
        (date: DateTime(2024, 2, 1), value: 2),
        (date: DateTime(2024, 2, 1), value: 3),
        (date: DateTime(2024, 2, 29), value: 4),
      ], past);

      expect(series, isNotNull);
      expect(series!.length, 29);
      expect(series[0], 5);
      expect(series[28], 4);
      expect(series[10], 0);
    });

    test('ignores entries from other months', () {
      final series = dailySeries([
        (date: DateTime(2024, 1, 31), value: 9),
        (date: DateTime(2024, 2, 3), value: 1),
        (date: DateTime(2024, 3, 1), value: 9),
      ], past);

      // Only one in-month day has data, so there is no trend to draw.
      expect(series, isNull);
    });

    test('returns null with fewer than two active days', () {
      expect(dailySeries(const [], past), isNull);
      expect(
        dailySeries([(date: DateTime(2024, 2, 5), value: 1)], past),
        isNull,
      );
    });
  });
}
