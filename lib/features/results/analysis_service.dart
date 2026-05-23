import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/chat_data_service.dart';
import '../expenses/cashew_transaction.dart';
import '../expenses/expenses_service.dart';
import '../health/health_service.dart';
import '../health/health_summary.dart';
import '../location/location_service.dart';
import '../location/timeline_entry.dart';
import '../prompts/prompt_config_service.dart';
import 'results_service.dart';

class AnalysisRunState {
  const AnalysisRunState({
    this.isRunning = false,
    this.lastError,
    this.lastRunAt,
  });

  final bool isRunning;
  final String? lastError;
  final DateTime? lastRunAt;

  AnalysisRunState copyWith({
    bool? isRunning,
    String? lastError,
    bool clearError = false,
    DateTime? lastRunAt,
  }) {
    return AnalysisRunState(
      isRunning: isRunning ?? this.isRunning,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }
}

final analysisRunProvider =
    StateNotifierProvider<AnalysisRunController, AnalysisRunState>(
  (ref) => AnalysisRunController(ref),
);

class AnalysisRunController extends StateNotifier<AnalysisRunState> {
  AnalysisRunController(this._ref) : super(const AnalysisRunState());

  final Ref _ref;
  final Random _random = Random();

  Future<void> runAnalysis() async {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true, clearError: true);

    try {
      final config = await _ref.read(promptConfigProvider.future);
      final chatData = await _ref.read(chatDataProvider.future);
      final expenses = _ref.read(expensesSummaryProvider);
      final location = _ref.read(locationHistoryProvider);
      final healthResult = await _ref.read(healthDataProvider.future);
      final healthSummary = HealthSummary.fromData(
        healthResult.points,
        todaySteps: healthResult.todaySteps,
      );

      final dataSnapshot = {
        'health': _healthText(healthSummary, healthResult),
        'expenses': _expensesText(expenses),
        'location': _locationText(location),
        'chat': _chatText(chatData),
      };

      final prompt = _renderPrompt(config, dataSnapshot);
      final output = _generateInsights(
        healthSummary: healthSummary,
        healthResult: healthResult,
        expenses: expenses,
        location: location,
        chatData: chatData,
        focus: config.focus,
      );

      final now = DateTime.now();
      final result = AnalysisResult(
        id: '${now.microsecondsSinceEpoch}-${_random.nextInt(9999)}',
        createdAt: now,
        title: 'Personal insights (${now.year}-${now.month}-${now.day})',
        prompt: prompt,
        output: output,
        dataSnapshot: dataSnapshot,
      );
      await _ref.read(analysisResultsProvider.notifier).addResult(result);

      state = state.copyWith(
        isRunning: false,
        clearError: true,
        lastRunAt: now,
      );
    } catch (error) {
      state = state.copyWith(
        isRunning: false,
        lastError: error.toString(),
      );
    }
  }
}

String _renderPrompt(PromptConfig config, Map<String, String> snapshot) {
  return config.template
      .replaceAll('{{focus}}', config.focus)
      .replaceAll('{{health}}', snapshot['health'] ?? 'No health data')
      .replaceAll('{{expenses}}', snapshot['expenses'] ?? 'No expense data')
      .replaceAll('{{location}}', snapshot['location'] ?? 'No location data')
      .replaceAll('{{chat}}', snapshot['chat'] ?? 'No chat data');
}

String _healthText(HealthSummary summary, HealthFetchResult raw) {
  final sleep = summary.sleep != null
      ? '${formatDuration(summary.sleep!.duration)} (${formatTime(summary.sleep!.startTime)}-${formatTime(summary.sleep!.endTime)})'
      : 'No sleep record';
  return 'Steps: ${summary.totalSteps}\n'
      'Heart rate: ${summary.latestHeartRate ?? 'N/A'} bpm\n'
      'Sleep: $sleep\n'
      'Workouts: ${summary.workoutCount}\n'
      'Walked: ${formatDistanceKm(summary.walkedDistanceKm)} km in ${formatDuration(summary.walkedDuration)}\n'
      'Source note: ${raw.stepsFromHealthConnectOnly ? 'Health Connect aggregate only' : 'Mixed providers'}';
}

String _expensesText(ExpensesSummary summary) {
  if (summary.transactions.isEmpty) return 'No expense data imported.';
  return 'Transactions: ${summary.transactions.length}\n'
      'Real expenses: ${summary.totalRealExpenses.toStringAsFixed(2)} ${summary.currency}\n'
      'Income: ${summary.totalIncome.toStringAsFixed(2)} ${summary.currency}\n'
      'Net surplus: ${summary.netSurplus.toStringAsFixed(2)} ${summary.currency}\n'
      'Burn rate: ${summary.burnRate != null ? '${(summary.burnRate! * 100).toStringAsFixed(1)}%' : 'N/A'}';
}

String _locationText(LocationHistorySummary summary) {
  if (summary.entries.isEmpty) return 'No location history imported.';
  if (!summary.hasMonthData) {
    return 'Location import available but no data in ${summary.monthLabel}.';
  }
  final topMode = summary.travelByMode.isNotEmpty ? summary.travelByMode.first : null;
  return 'Month: ${summary.monthLabel}\n'
      'Distance: ${summary.totalDistanceKm.toStringAsFixed(1)} km\n'
      'Trips: ${summary.activityCount}, Visits: ${summary.visitCount}\n'
      'Top travel mode: ${topMode?.label ?? 'N/A'}';
}

String _chatText(ChatData data) {
  if (!data.hasContent) return 'No chat context provided.';
  final trimmed = data.content.trim();
  if (trimmed.length <= 1200) return trimmed;
  return '${trimmed.substring(0, 1200)}\n...[truncated]';
}

String _generateInsights({
  required HealthSummary healthSummary,
  required HealthFetchResult healthResult,
  required ExpensesSummary expenses,
  required LocationHistorySummary location,
  required ChatData chatData,
  required String focus,
}) {
  final lines = <String>[
    'Focus: $focus',
    '',
    'Highlights',
  ];

  if (healthSummary.totalSteps > 0) {
    lines.add(
      '- You logged ${healthSummary.totalSteps} steps today. '
      '${healthSummary.totalSteps < 6000 ? 'Consider one extra 25-30 minute walk.' : 'Good movement volume for the day.'}',
    );
  } else {
    lines.add('- Health step data is missing today; check Health permissions/sync.');
  }

  if (expenses.transactions.isNotEmpty) {
    final burn = expenses.burnRate;
    if (burn != null) {
      lines.add(
        '- Burn rate is ${(burn * 100).toStringAsFixed(1)}%. '
        '${burn > 0.9 ? 'Spending is close to income; reduce optional costs this week.' : 'Current spending is within a safer range.'}',
      );
    }
    lines.add(
      '- Net surplus is ${expenses.netSurplus.toStringAsFixed(2)} ${expenses.currency}.',
    );
  } else {
    lines.add('- Expense data is not loaded; import your CSV for money insights.');
  }

  if (location.hasMonthData) {
    lines.add(
      '- You traveled ${location.totalDistanceKm.toStringAsFixed(1)} km this month over ${location.activityCount} trips.',
    );
    final topMode = location.travelByMode.isNotEmpty ? location.travelByMode.first : null;
    if (topMode != null) {
      lines.add(
        '- Main travel mode is ${topMode.label} (${topMode.distanceKm.toStringAsFixed(1)} km).',
      );
    }
  } else {
    lines.add('- Location data for this month is unavailable.');
  }

  if (chatData.hasContent) {
    lines.add(
      '- Chat context provided (${chatData.content.trim().length} chars) and included in analysis.',
    );
  } else {
    lines.add('- Chat context is empty; add recent conversations for deeper personalization.');
  }

  lines
    ..add('')
    ..add('Next actions (7 days)')
    ..add(
      '- Set one health target (steps/sleep), one spending cap, and one mobility habit; review progress after your next analysis run.',
    )
    ..add(
      '- Re-run analysis after importing fresh data to track trend changes in results history.',
    );

  if (healthResult.stepsFromHealthConnectOnly) {
    lines
      ..add('')
      ..add(
        'Note: Step count appears to come from Health Connect aggregate data only; Samsung Health app totals may differ until full sync.',
      );
  }

  return lines.join('\n');
}
