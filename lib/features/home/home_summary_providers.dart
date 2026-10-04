import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/features/analysis/analysis_result_period.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/results/selected_checklist_result_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Progress through the current week of the active monthly checklist.
class ChecklistSummary {
  const ChecklistSummary({
    required this.monthLabel,
    required this.weekNumber,
    required this.weekCount,
    required this.done,
    required this.total,
  });

  final String monthLabel;
  final int weekNumber;
  final int weekCount;
  final int done;
  final int total;

  double get fraction => total == 0 ? 0 : done / total;
}

final homeChecklistSummaryProvider = Provider<ChecklistSummary?>((ref) {
  final results = ref.watch(analysisResultsProvider).valueOrNull;
  if (results == null) return null;
  final withChecklist = analysisResultsWithChecklist(results);
  if (withChecklist.isEmpty) return null;

  final id = resolveSelectedChecklistResultId(
    withChecklist: withChecklist,
    storedId: ref.watch(selectedChecklistResultIdProvider),
  );
  if (id == null) return null;

  final result = withChecklist.firstWhere((r) => r.id == id);
  final report = InsightsReportParser.parse(result.output);
  final period = result.analysisPeriod;
  final weekCount = math.max(
    report.checklistWeekCount,
    period.checklistWeekCount,
  );
  if (weekCount == 0) return null;

  final weekIndex = resolveDefaultChecklistWeekIndex(
    period: period,
    weekCount: weekCount,
  );
  final state = ref
      .watch(
        insightChecklistProvider(
          insightChecklistStorageKey(result.id, weekIndex),
        ),
      )
      .valueOrNull;

  return ChecklistSummary(
    monthLabel: period.checklistMonthLabel,
    weekNumber: weekIndex + 1,
    weekCount: weekCount,
    done: state?.completed.length ?? 0,
    total: report.actionsForWeekIndex(weekIndex).length,
  );
});

enum SetupStepId { folder, profile, data, ai }

class SetupStep {
  const SetupStep({
    required this.id,
    required this.title,
    required this.hint,
    required this.done,
    this.optional = false,
  });

  final SetupStepId id;
  final String title;
  final String hint;
  final bool done;
  final bool optional;
}

/// First-run checklist; empty once the required steps are done.
final homeSetupStepsProvider = Provider<List<SetupStep>>((ref) {
  final folder = ref.watch(dataFolderSettingsProvider).valueOrNull;
  final config = ref.watch(promptConfigProvider).valueOrNull;
  final ai = ref.watch(aiSettingsProvider).valueOrNull;
  final stats = ref.watch(homeTileStatsProvider);

  // Avoid flashing the card while settings are still loading.
  if (folder == null || config == null || ai == null) return const [];

  final hasData = homeFeatures.any(
    (f) => f.id != HomeFeatureId.dashboard && stats[f.id] != null,
  );
  final hasKey =
      !ai.enableApiCalls ||
      ai.openAiApiKey.isNotEmpty ||
      ai.geminiApiKey.isNotEmpty ||
      ai.anthropicApiKey.isNotEmpty;

  final steps = [
    SetupStep(
      id: SetupStepId.folder,
      title: 'Choose a data folder',
      hint: 'Where your exports and reports live',
      done: folder.hasFolder,
    ),
    SetupStep(
      id: SetupStepId.profile,
      title: 'Complete your profile',
      hint: 'Context the AI uses for your insights',
      done: config.isPersonalInfoComplete,
    ),
    SetupStep(
      id: SetupStepId.data,
      title: 'Load some data',
      hint: 'Open a tile below to import health, spending…',
      done: hasData,
    ),
    SetupStep(
      id: SetupStepId.ai,
      title: 'Add an AI key',
      hint: 'Optional — without one, on-device summaries are used',
      done: hasKey,
      optional: true,
    ),
  ];

  final requiredDone = steps.where((s) => !s.optional).every((s) => s.done);
  return requiredDone ? const [] : steps;
});
