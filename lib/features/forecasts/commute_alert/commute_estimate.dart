import 'dart:math' as math;

import 'package:personal/features/forecasts/commute_alert/commute_profile.dart';
import 'package:personal/features/forecasts/life/life_forecast_math.dart';

/// Google's figure for one trip, in minutes.
typedef TrafficReading = ({int withTraffic, int withoutTraffic});

/// Minutes from walking out of the door to riding off, by default.
const defaultCommutePrepMinutes = 3;

/// Minutes added when the day is forecast to be wet, as the dashboard's
/// commute forecast does.
const commuteRainBuffer = 10;

/// When to leave on one day, and why.
class LeaveEstimate {
  const LeaveEstimate({
    required this.leaveAt,
    required this.tripMinutes,
    required this.target,
    required this.typical,
    required this.safe,
    required this.prepMinutes,
    this.rainBuffer = 0,
    this.traffic,
    this.aiReason,
  });

  /// When to walk out of the door, minutes after midnight.
  final int leaveAt;

  /// Door to work, including getting going and any rain allowance.
  final int tripMinutes;

  /// When to be at work, minutes after midnight.
  final int target;

  /// Your own trips: median and 8-in-10 minutes.
  final double typical;
  final double safe;
  final int prepMinutes;
  final int rainBuffer;
  final TrafficReading? traffic;

  /// The AI's one-line reason when it set [leaveAt]; null otherwise.
  final String? aiReason;

  LeaveEstimate withAi({required int leaveAt, required String reason}) =>
      LeaveEstimate(
        leaveAt: leaveAt,
        tripMinutes: target - leaveAt,
        target: target,
        typical: typical,
        safe: safe,
        prepMinutes: prepMinutes,
        rainBuffer: rainBuffer,
        traffic: traffic,
        aiReason: reason,
      );

  String titleAt(DateTime now) {
    final nowMinutes = now.hour * 60 + now.minute;
    return leaveAt <= nowMinutes
        ? 'Leave for work now'
        : 'Leave for work at ${clockLabel(leaveAt)}';
  }

  String get body {
    final t = traffic;
    return [
      'To reach work by ${clockLabel(target)}, allow $tripMinutes min '
          'door to door.',
      if (aiReason != null && aiReason!.isNotEmpty) 'AI: $aiReason',
      if (t != null)
        'Google traffic: ${t.withTraffic} min riding${_trafficNote(t)}, '
            'plus $prepMinutes to get going.'
      else
        'Live traffic unavailable, so this uses your own trips only.',
      if (rainBuffer > 0) 'Rain expected: $rainBuffer min extra.',
      'Your trips: usually ${typical.round()} min, '
          '${safe.round()} on slow days.',
    ].join(' ');
  }
}

/// Rounds down to 5 minutes, so the advice is never later than the maths.
int _floor5(double minutes) => (minutes / 5).floor() * 5;

/// When to leave going by your own trips alone: the arrival target minus a
/// trip that covered 8 in 10 of them.
int historyLeaveAt(CommuteProfile profile, DateTime day) {
  final s = profile.statsFor(day);
  return _floor5(s.target - s.safe);
}

/// When to leave on [day], combining Google's live traffic ([traffic], null
/// when unavailable) with your timeline.
///
/// Google's time covers riding only, so [prepMinutes] (door to riding off)
/// is added to it; your timeline trips are already door to door. Google's
/// time is then scaled by how much slower your worst usual trips are than
/// your typical one (its estimate is a typical trip, and you want to be on
/// time on bad days too). Once enough days have both Google's figure and
/// your actual trip, it is also corrected by how your trips compare with
/// Google's; until then it is averaged with your own 8-in-10 trip time.
LeaveEstimate estimateLeave(
  CommuteProfile profile,
  DateTime day, {
  TrafficReading? traffic,
  int prepMinutes = defaultCommutePrepMinutes,
}) {
  final s = profile.statsFor(day);
  final spread = s.typical > 0 ? math.max(1.0, s.safe / s.typical) : 1.0;
  final calibration = profile.calibration;

  final double trip;
  if (traffic == null) {
    trip = s.safe;
  } else {
    final door = (traffic.withTraffic + prepMinutes).toDouble();
    trip = calibration != null
        ? door * calibration * spread
        : (door * spread + s.safe) / 2;
  }
  final rain = (profile.weatherOn(day)?.wet ?? false) ? commuteRainBuffer : 0;
  final leaveAt = _floor5(s.target - trip - rain);

  return LeaveEstimate(
    leaveAt: leaveAt,
    tripMinutes: s.target - leaveAt,
    target: s.target,
    typical: s.typical,
    safe: s.safe,
    prepMinutes: prepMinutes,
    rainBuffer: rain,
    traffic: traffic,
  );
}

String _trafficNote(TrafficReading t) {
  final extra = t.withTraffic - t.withoutTraffic;
  if (t.withoutTraffic <= 0) return '';
  if (extra >= 3) return ' ($extra more than on clear roads)';
  return ' (roads are clear)';
}
