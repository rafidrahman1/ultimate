import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/storage/data_folder_settings_service.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/features/home/home_tile_stats.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

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
  final folder = ref.watch(dataFolderSettingsProvider).value;
  final config = ref.watch(promptConfigProvider).value;
  final ai = ref.watch(aiSettingsProvider).value;
  final stats = ref.watch(homeTileStatsProvider);

  // Avoid flashing the card while settings are still loading.
  if (folder == null || config == null || ai == null) return const [];

  final hasData = homeFeatures.any((f) => stats[f.id] != null);
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
