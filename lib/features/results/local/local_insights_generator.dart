import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/features/analysis/ui/analysis_data_preview.dart';
import 'package:personal/features/calendar/data/calendar_event.dart';
import 'package:personal/features/expenses/data/cashew_transaction.dart';
import 'package:personal/features/game_activity/game_activity_session.dart';
import 'package:personal/features/health/data/health_service.dart';
import 'package:personal/features/health/data/health_summary.dart';
import 'package:personal/features/location/data/timeline_activity.dart';

/// One bold-titled bullet, the shape `InsightsReportParser` reads.
String _item(String title, String body) => '- **$title**: $body';

String generateInsights({
  required AnalysisPeriod period,
  required AnalysisSourceSelection selection,
  required MonthlyHealthSummary monthlySummary,
  required MonthlyHealthFetchResult monthlyHealth,
  required ExpensesSummary expenses,
  required LocationSummary location,
  required GameActivitySummary gameActivity,
  required CalendarSummary calendar,
  required String focus,
}) {
  final lines = <String>[
    'Focus: $focus',
    'Data month: ${period.dataRangeLabel}',
    'Checklist month: ${period.checklistMonthLabel}',
    '',
    '### **Patterns & Anomalies**',
    '',
  ];

  if (selection.includes(AnalysisDataSourceId.health)) {
    if (monthlyHealth.hasData) {
      lines.add(
        _item(
          'Sleep',
          'Data available for ${monthlySummary.periodRangeLabel}.',
        ),
      );
    } else {
      lines.add(
        _item(
          'Health data missing',
          'Nothing for ${monthlySummary.periodRangeLabel}; check Samsung Health sync.',
        ),
      );
    }
  }

  if (selection.includes(AnalysisDataSourceId.expenses) &&
      expenses.transactions.isNotEmpty) {
    final burn = expenses.burnRate;
    final expensePeriod = expenses.periodRangeLabel ?? period.dataRangeLabel;
    if (burn != null) {
      lines.add(
        _item(
          'Burn rate',
          '${(burn * 100).toStringAsFixed(1)}% for $expensePeriod. '
              '${burn > 0.9 ? 'Spending is close to income; tighten optional costs.' : 'Current spending is within a safer range.'}',
        ),
      );
    }
    lines.add(
      '- Net surplus is ${expenses.netSurplus.toStringAsFixed(2)} ${expenses.currency} ($expensePeriod).',
    );
  } else if (selection.includes(AnalysisDataSourceId.expenses)) {
    lines.add(
      '- Expense data is not loaded for ${period.dataRangeLabel}; import your CSV for money insights.',
    );
  }

  if (selection.includes(AnalysisDataSourceId.location)) {
    final monthBikes = location
        .activitiesInRange(period.dataMonthStart, period.dataMonthEnd)
        .where(
          (activity) => activity.isMotorcycling && activity.distanceMeters > 0,
        )
        .toList();
    if (monthBikes.isNotEmpty) {
      final km =
          (monthBikes.fold<double>(
                    0,
                    (sum, activity) => sum + activity.distanceMeters,
                  ) /
                  1000)
              .toStringAsFixed(2);
      lines.add(
        _item(
          'Motorcycle distance',
          '$km km across ${monthBikes.length} timeline segments.',
        ),
      );
    } else {
      lines.add(
        _item(
          'No motorcycle data',
          'Location timeline has no motorcycle segments for ${period.dataRangeLabel}.',
        ),
      );
    }
  }

  if (selection.includes(AnalysisDataSourceId.gameActivity) &&
      gameActivity.sessions.isNotEmpty) {
    lines.add(
      _item(
        'Gaming',
        '${gameActivity.sessions.length} sessions '
            '(${GameActivitySummary.formatPromptDuration(gameActivity.totalPlayTime)}) '
            'across ${gameActivity.uniqueGameCount} titles.',
      ),
    );
  } else if (selection.includes(AnalysisDataSourceId.gameActivity)) {
    lines.add(
      _item(
        'No game data',
        'Not loaded for ${period.dataRangeLabel}; import a GameActivity_Export* file.',
      ),
    );
  }

  if (selection.includes(AnalysisDataSourceId.calendar) &&
      calendar.events.isNotEmpty) {
    final holidayNote = calendar.holidayGroupCount > 0
        ? ', including ${calendar.holidayGroupCount} Bangladesh public holidays '
              '(${calendar.holidayCount} days)'
        : '';
    lines.add(
      _item(
        'Calendar',
        '${calendar.events.length} events in scope '
            '(${calendar.upcomingEvents.length} upcoming$holidayNote).',
      ),
    );
  } else if (selection.includes(AnalysisDataSourceId.calendar)) {
    lines.add(
      _item(
        'Calendar not connected',
        'Sync your schedule for planning insights.',
      ),
    );
  }

  if (selection.includes(AnalysisDataSourceId.health) &&
      !monthlyHealth.hasData) {
    lines
      ..add('')
      ..add(
        'Note: No Samsung Health data in ${monthlySummary.periodRangeLabel}; open Samsung Health to sync via Health Connect.',
      );
  }

  lines
    ..add('')
    ..add('### **Clear Next Actions (${period.checklistMonthLabel})**');

  for (final week in period.checklistWeeks) {
    lines
      ..add('')
      ..add('##### Week ${week.weekNumber}: ${week.isoRangeLabel}')
      ..add('')
      ..add(
        week.weekNumber == 1
            ? _item(
                'Set your targets',
                'Pick one health target, one spending cap, and one schedule '
                    'habit for ${period.checklistMonthLabel}.',
              )
            : _item(
                'Keep the habits going',
                'Repeat the week 1 targets and note what got in the way.',
              ),
      );
  }
  lines
    ..add('')
    ..add(
      'Re-run analysis after the month ends to update patterns and the next checklist.',
    );

  return lines.join('\n');
}
