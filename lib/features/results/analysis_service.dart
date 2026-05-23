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
import '../settings/ai_settings_service.dart';
import 'ai_client.dart';
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
  final AiClient _aiClient = const AiClient();

  Future<void> runAnalysis() async {
    if (state.isRunning) return;
    state = state.copyWith(isRunning: true, clearError: true);

    try {
      final config = await _ref.read(promptConfigProvider.future);
      final chatData = await _ref.read(chatDataProvider.future);
      final expenses = _ref.read(expensesSummaryProvider);
      final location = _ref.read(locationHistoryProvider);
      final weeklyHealth = await _ref.read(weeklyHealthDataProvider.future);
      final weeklySummary = WeeklyHealthSummary.fromWeeklyFetch(weeklyHealth);

      final dataSnapshot = {
        'health': _healthText(weeklySummary),
        'expenses': _expensesText(expenses),
        'location': _locationText(location),
        'chat': _chatText(chatData),
      };

      final prompt = _renderPrompt(config, dataSnapshot);
      final aiSettings = await _ref.read(aiSettingsProvider.future);
      final output = aiSettings.enableApiCalls
          ? await _aiClient.generate(settings: aiSettings, prompt: prompt)
          : _generateInsights(
              weeklySummary: weeklySummary,
              weeklyHealth: weeklyHealth,
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

String _healthText(WeeklyHealthSummary summary) {
  final sleep = summary.sleepNightsTracked > 0
      ? '${formatDuration(summary.avgSleepPerDay)} avg per night '
          '(bed ${summary.avgBedtime != null ? formatTime(summary.avgBedtime!) : 'N/A'}, '
          'wake ${summary.avgWakeTime != null ? formatTime(summary.avgWakeTime!) : 'N/A'}, '
          '${summary.sleepNightsTracked} nights)'
      : 'No sleep records in period';
  final heartSubtitle = summary.latestHeartRateTime != null
      ? ' (as of ${formatTime(summary.latestHeartRateTime!)})'
      : '';
  final weightLine = summary.latestWeightKg != null
      ? 'Weight: ${formatWeightKg(summary.latestWeightKg)} kg'
          '${summary.latestWeightTime != null ? ' (as of ${formatTime(summary.latestWeightTime!)})' : ''}'
      : 'Weight: N/A';
  final bmiLine = summary.bmi != null
      ? 'BMI: ${formatBmi(summary.bmi)}'
          '${summary.heightMeters != null ? ' (height ${(summary.heightMeters! * 100).toStringAsFixed(0)} cm)' : ''}'
      : 'BMI: N/A';
  return 'Period: ${summary.periodRangeLabel}\n'
      'Source: Samsung Health (via Health Connect)\n'
      'Steps: ${summary.avgStepsPerDay.round()} avg per day\n'
      'Heart rate: ${summary.latestHeartRate ?? 'N/A'} bpm$heartSubtitle (current)\n'
      '$weightLine\n'
      '$bmiLine\n'
      'Sleep: $sleep';
}

String _expensesText(ExpensesSummary summary) {
  if (summary.transactions.isEmpty) return 'No expense data imported.';
  final range = summary.periodRangeLabel;
  final periodLine =
      range != null ? 'Period: $range\n' : 'Period: unknown\n';
  return '$periodLine'
      'Transactions: ${summary.transactions.length}\n'
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
  final range = summary.periodRangeLabel;
  final periodLine = range != null ? 'Period: $range\n' : '';
  return '${periodLine}Month: ${summary.monthLabel}\n'
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
  required WeeklyHealthSummary weeklySummary,
  required WeeklyHealthFetchResult weeklyHealth,
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

  final avgSteps = weeklySummary.avgStepsPerDay.round();
  if (avgSteps > 0) {
    lines.add(
      '- Weekly average is $avgSteps steps per day (${weeklySummary.periodRangeLabel}). '
      '${avgSteps < 6000 ? 'Consider one extra 25-30 minute walk on low days.' : 'Good movement volume for the week.'}',
    );
  } else {
    lines.add(
      '- Health step data is missing for ${weeklySummary.periodRangeLabel}; check Samsung Health sync.',
    );
  }

  if (expenses.transactions.isNotEmpty) {
    final burn = expenses.burnRate;
    final expensePeriod = expenses.periodRangeLabel ?? 'imported transactions';
    if (burn != null) {
      lines.add(
        '- Burn rate is ${(burn * 100).toStringAsFixed(1)}% for $expensePeriod. '
        '${burn > 0.9 ? 'Spending is close to income; reduce optional costs this week.' : 'Current spending is within a safer range.'}',
      );
    }
    lines.add(
      '- Net surplus is ${expenses.netSurplus.toStringAsFixed(2)} ${expenses.currency} ($expensePeriod).',
    );
  } else {
    lines.add('- Expense data is not loaded; import your CSV for money insights.');
  }

  if (location.hasMonthData) {
    final locationPeriod = location.periodRangeLabel ?? location.monthLabel;
    lines.add(
      '- You traveled ${location.totalDistanceKm.toStringAsFixed(1)} km ($locationPeriod) over ${location.activityCount} trips.',
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

  if (!weeklyHealth.hasData) {
    lines
      ..add('')
      ..add(
        'Note: No Samsung Health data in ${weeklySummary.periodRangeLabel}; open Samsung Health to sync via Health Connect.',
      );
  }

  return lines.join('\n');
}
