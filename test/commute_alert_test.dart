import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/forecasts/commute_alert/commute_ai.dart';
import 'package:personal/features/forecasts/commute_alert/commute_estimate.dart';
import 'package:personal/features/forecasts/commute_alert/commute_profile.dart';
import 'package:personal/features/forecasts/commute_alert/google_traffic_client.dart';
import 'package:personal/features/location/data/timeline_profile.dart';

CommuteProfile _profile({
  double? calibration,
  Map<DateTime, CommuteWeather> weather = const {},
}) => CommuteProfile(
  home: const GeoPoint(23.78, 90.40),
  work: const GeoPoint(23.75, 90.39),
  overall: const CommuteTripStats(
    typical: 30,
    safe: 40,
    target: 9 * 60,
    trips: 20,
  ),
  byWeekday: const {
    DateTime.monday: CommuteTripStats(
      typical: 40,
      safe: 50,
      target: 9 * 60,
      trips: 4,
    ),
  },
  commuteWeekdays: const {1, 2, 3, 4, 7},
  weekendDays: const [DateTime.friday, DateTime.saturday],
  holidays: {DateTime(2026, 12, 16)},
  calibration: calibration,
  weather: weather,
  recentTrips: [(day: DateTime(2026, 11, 24), left: 490, arrived: 525)],
);

void main() {
  group('parseRoutesResponse', () {
    test('reads durations as minutes', () {
      final r = parseRoutesResponse(
        '{"routes":[{"duration":"1830s","staticDuration":"1200s"}]}',
      );
      expect(r.withTraffic, 31);
      expect(r.withoutTraffic, 20);
    });

    test('throws when there is no route', () {
      expect(() => parseRoutesResponse('{}'), throwsFormatException);
    });
  });

  group('estimateLeave', () {
    // Tuesday: uses overall stats (typical 30, safe 40, target 09:00).
    final tue = DateTime(2026, 12, 1);

    test('without traffic uses the 8-in-10 trip', () {
      final e = estimateLeave(_profile(), tue);
      expect(e.leaveAt, 8 * 60 + 20);
      expect(e.tripMinutes, 40);
      expect(e.titleAt(tue), 'Leave for work at 08:20');
    });

    test('adds getting going to Google, averaged with your trips', () {
      // (33 + 3) * (40/30) = 48, averaged with 40 -> 44 -> 08:16 -> 08:15.
      final e = estimateLeave(
        _profile(),
        tue,
        traffic: (withTraffic: 33, withoutTraffic: 22),
      );
      expect(e.leaveAt, 8 * 60 + 15);
      expect(e.body, contains('11 more than on clear roads'));
      expect(e.body, contains('plus 3 to get going'));
    });

    test('calibrated traffic is scaled to your trips', () {
      // (27 + 3) * 1.2 * (40/30) = 48 -> 08:12 -> 08:10.
      final e = estimateLeave(
        _profile(calibration: 1.2),
        tue,
        traffic: (withTraffic: 27, withoutTraffic: 27),
      );
      expect(e.leaveAt, 8 * 60 + 10);
    });

    test('a wet day leaves earlier', () {
      final p = _profile(weather: {tue: (wet: true, note: 'Rain 80%')});
      final e = estimateLeave(p, tue);
      expect(e.rainBuffer, commuteRainBuffer);
      expect(e.leaveAt, 8 * 60 + 10);
    });

    test('says now once the time has passed', () {
      final e = estimateLeave(_profile(), tue);
      expect(
        e.titleAt(tue.add(const Duration(hours: 8, minutes: 30))),
        'Leave for work now',
      );
    });

    test('uses the weekday stats when present', () {
      final mon = DateTime(2026, 11, 30);
      expect(historyLeaveAt(_profile(), mon), 8 * 60 + 10);
    });
  });

  group('commute AI', () {
    final tue = DateTime(2026, 12, 1);
    final baseline = estimateLeave(
      _profile(),
      tue,
      traffic: (withTraffic: 33, withoutTraffic: 22),
    ); // 08:15

    test('takes a sensible leave time and reason', () {
      final e = parseCommuteAiResponse(
        'Sure: {"leaveAt": "08:05", "reason": "Tuesdays run slow."}',
        baseline,
      );
      expect(e?.leaveAt, 8 * 60 + 5);
      expect(e?.aiReason, 'Tuesdays run slow.');
      expect(e?.body, contains('AI: Tuesdays run slow.'));
    });

    test('rejects replies far from the baseline or too late to ride', () {
      expect(parseCommuteAiResponse('{"leaveAt": "07:00"}', baseline), isNull);
      // 09:00 - 33 - 3 = 08:24 at the latest.
      expect(parseCommuteAiResponse('{"leaveAt": "08:30"}', baseline), isNull);
      expect(parseCommuteAiResponse('no idea', baseline), isNull);
    });

    test('prompt carries trips, traffic and getting going', () {
      final prompt = buildCommuteAiPrompt(
        profile: _profile(),
        day: tue,
        now: tue.add(const Duration(hours: 7)),
        baseline: baseline,
        travelMode: 'Motorbike',
      );
      expect(prompt, contains('takes 3 min'));
      expect(prompt, contains('33 min with traffic'));
      expect(prompt, contains('2026-11-24 (Tue) | 08:10 | 08:45 | 35'));
    });
  });

  group('CommuteProfile', () {
    test('working days skip weekends, holidays and unusual weekdays', () {
      final p = _profile();
      expect(p.isCommuteDay(DateTime(2026, 12, 1)), isTrue); // Tue
      expect(p.isCommuteDay(DateTime(2026, 12, 4)), isFalse); // Fri
      expect(p.isCommuteDay(DateTime(2026, 12, 3)), isTrue); // Thu
      expect(p.isCommuteDay(DateTime(2026, 12, 16)), isFalse); // holiday
    });

    test('survives a JSON round trip', () {
      final p = _profile(calibration: 1.1);
      final back = CommuteProfile.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
      expect(back.statsFor(DateTime(2026, 11, 30)).typical, 40);
    });
  });
}
