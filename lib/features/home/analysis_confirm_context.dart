import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

String buildInsightEngineLabel(
  AiSettings aiSettings, {
  required String onDeviceLabel,
}) {
  if (!aiSettings.enableApiCalls) return onDeviceLabel;

  final model = aiSettings.provider == AiProvider.openai
      ? aiSettings.openAiModel
      : aiSettings.geminiModel;
  return 'Cloud AI (${aiSettings.provider.name} · $model)';
}

Future<AnalysisRunPreview?> loadAnalysisRunPreview(
  WidgetRef ref,
  BuildContext context, {
  required String onDeviceInsightLabel,
}) async {
  final period = ref.read(analysisPeriodProvider);
  final expenses = ref.read(expensesForAnalysisProvider);
  final expensesSource = ref.read(expensesSummaryProvider);
  final location = ref.read(locationForAnalysisProvider);
  final gameActivity = ref.read(gameActivityForAnalysisProvider);
  final calendar = ref.read(calendarForAnalysisProvider);
  final calendarUpcoming = ref.read(calendarForDisplayProvider);
  final healthAsync = ref.read(monthlyHealthDataProvider);
  final aiSettings = await ref.read(aiSettingsProvider.future);
  final promptConfig = await ref.read(promptConfigProvider.future);

  if (!context.mounted) return null;

  return buildAnalysisRunPreview(
    period: period,
    healthFetch: healthAsync.valueOrNull,
    healthLoading: healthAsync.isLoading,
    expenses: expenses,
    expensesSource: expensesSource,
    location: location,
    gameActivity: gameActivity,
    calendar: calendar,
    calendarUpcomingSource: calendarUpcoming,
    insightEngineLabel: buildInsightEngineLabel(
      aiSettings,
      onDeviceLabel: onDeviceInsightLabel,
    ),
    workAddress: promptConfig.workAddress,
    workHours: promptConfig.workHours,
    weekendDays: promptConfig.weekendDays,
    monthlyIncomeBdt: promptConfig.analysisMonthlyIncomeBdt,
    monthlyBudgetBdt: promptConfig.monthlyBudgetBdt,
    financialInstruction: promptConfig.financialInstruction,
  );
}
