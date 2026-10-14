import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/health/data/vitals_models.dart';
import 'package:personal/features/location/analysis/work_arrival_stats.dart';
import 'package:personal/features/location/data/timeline_activity.dart';

/// Where a prediction sits in the list's filter chips and the chooser.
enum PredictionGroup {
  money('Money'),
  body('Body'),
  life('Life');

  const PredictionGroup(this.label);

  final String label;
}

/// What a life forecast is about. [name] is the key used for cards, panels,
/// the chooser and stored AI answers.
enum LifeForecastKind {
  weight(
    'Weight trend',
    PredictionGroup.body,
    'Where your weight is heading in 30 days',
  ),
  activity(
    'Activity ahead',
    PredictionGroup.body,
    'Steps and workouts expected over the next 7 days',
  ),
  workouts(
    'Workout pace',
    PredictionGroup.body,
    'Workouts per week and the days you usually train',
  ),
  heartRate(
    'Resting heart rate',
    PredictionGroup.body,
    'Resting heart rate in two weeks',
  ),
  recovery(
    'Recovery',
    PredictionGroup.body,
    'How sleep moves your resting heart rate tomorrow',
  ),
  billAlerts(
    'Bill watch',
    PredictionGroup.money,
    'Bills that rose or are late against their history',
  ),
  holidaySpend(
    'Holiday spending',
    PredictionGroup.money,
    'Extra spending expected around upcoming holidays',
  ),
  commute(
    'Leave for work',
    PredictionGroup.life,
    'The best time to leave home for work on your next working day',
  ),
  checklistThemes(
    'Checklist weak spots',
    PredictionGroup.life,
    'The kind of checklist item you tend to miss',
  ),
  bestDay(
    'Best day to plan',
    PredictionGroup.life,
    'The coming day that suits something demanding',
  );

  const LifeForecastKind(this.label, this.group, this.blurb);

  final String label;
  final PredictionGroup group;
  final String blurb;

  static LifeForecastKind? byName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return null;
  }
}

/// Progress of one checklist week, for the checklist-pace forecast.
class ChecklistWeekProgress {
  const ChecklistWeekProgress({
    required this.weekNumber,
    required this.start,
    required this.end,
    required this.total,
    required this.done,
    required this.failed,
    this.byCategory = const {},
  });

  final int weekNumber;
  final DateTime start;
  final DateTime end;
  final int total;
  final int done;
  final int failed;

  /// Items and completions per checklist category (Health, Expenses, ...).
  final Map<String, ({int total, int done})> byCategory;
}

class ChecklistProgress {
  const ChecklistProgress({required this.title, required this.weeks});

  final String title;
  final List<ChecklistWeekProgress> weeks;
}

/// Everything the life forecasts read, gathered once so the maths and the AI
/// prompts see the same data.
class LifeInputs {
  const LifeInputs({
    required this.now,
    this.nights = const [],
    this.vitals,
    this.work = WorkArrivalStats.empty,
    this.events = const [],
    this.games = const [],
    this.checklist,
    this.dailySpend = const {},
    this.fitnessGoal = '',
    this.ledger = const [],
    this.spending = const [],
    this.activities = const [],
    this.placeVisits = const [],
    this.placeNames = const {},
    this.currency = '',
    this.weekendDays = const [],
  });

  final DateTime now;

  /// Nights with sleep data, oldest first.
  final List<DailySleepEntry> nights;
  final VitalsSummary? vitals;
  final WorkArrivalStats work;
  final List<CalendarEvent> events;
  final List<GameActivitySession> games;
  final ChecklistProgress? checklist;

  /// Real spending per local day.
  final Map<DateTime, double> dailySpend;
  final String fitnessGoal;

  /// The whole expense export, every entry.
  final List<CashewTransaction> ledger;

  /// The export with the categories you excluded from spending removed.
  final List<CashewTransaction> spending;
  final List<TimelineActivity> activities;
  final List<TimelinePlaceVisit> placeVisits;
  final Map<String, String> placeNames;
  final String currency;

  /// Weekday numbers (DateTime.monday..sunday) that are your days off. Empty
  /// means the Bangladesh default, Friday and Saturday.
  final List<int> weekendDays;

  DateTime get today => DateTime(now.year, now.month, now.day);
}

/// One computed forecast: a baseline the app worked out itself, plus the raw
/// data text and the question an AI refinement is given to redo the work.
class LifeForecast {
  const LifeForecast({
    required this.kind,
    required this.headline,
    required this.detail,
    required this.signature,
    required this.rawData,
    required this.question,
    this.date,
    this.attention = false,
    this.notes = const [],
    this.leavePlan = const {},
  });

  final LifeForecastKind kind;
  final String headline;
  final String detail;

  /// When the predicted event lands; null for figures without a date.
  final DateTime? date;

  /// Departure minutes after midnight for each upcoming working day, used to
  /// schedule reminders ahead. Empty for forecasts that are not commutes.
  final Map<DateTime, int> leavePlan;

  /// True when the figure deserves a highlighted card.
  final bool attention;

  /// How the baseline was worked out, shown in the detail panel.
  final List<String> notes;

  /// Changes when the underlying data does, so an AI answer made for older
  /// data can be recognised as stale.
  final String signature;

  /// The raw rows an AI refinement receives and calculates from.
  final String rawData;

  /// What the AI is asked to work out from [rawData].
  final String question;

  String get key => kind.name;
  String get label => kind.label;
}
