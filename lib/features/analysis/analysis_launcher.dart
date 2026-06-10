import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/features/home/analysis_confirm_dialog.dart';
import 'package:personal/features/home/progress_confirm_dialog.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/analysis_service.dart';
import 'package:personal/features/results/result_detail_screen.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/features/results/selected_checklist_result_service.dart';

AnalysisResult? resolveChecklistSource(WidgetRef ref) {
  final results = ref.read(analysisResultsProvider).valueOrNull ?? [];
  final withChecklist = analysisResultsWithChecklist(results);
  final selectedChecklistId = ref.read(selectedChecklistResultIdProvider);
  final checklistSourceId = resolveSelectedChecklistResultId(
    withChecklist: withChecklist,
    storedId: selectedChecklistId,
  );
  if (checklistSourceId == null) return null;
  return withChecklist.firstWhere((r) => r.id == checklistSourceId);
}

Future<bool> ensurePersonalInformation(BuildContext context, WidgetRef ref) async {
  final config = ref.read(promptConfigProvider).valueOrNull;
  if (config?.isPersonalInfoComplete ?? false) return true;

  final missing = config?.missingPersonalInfoLabels ?? const [];
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Personal information required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fill in your personal profile before running analysis.',
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Still needed:'),
            const SizedBox(height: 4),
            ...missing.map(
              (label) => Text('• $label'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.pushNamed(context, AppRoutes.personalInformation);
          },
          child: const Text('Open profile'),
        ),
      ],
    ),
  );

  return false;
}

Future<bool> ensureAnalysisFolder(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(dataFolderSettingsProvider).valueOrNull;
  final hasFolder = settings?.hasFolder ?? false;
  if (hasFolder) return true;

  final needsReselect = settings?.needsReselect ?? false;
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Data folder required'),
      content: Text(
        needsReselect
            ? 'Re-select your data folder in General settings '
                'so Android can write files there.'
            : 'Choose a data folder in General settings before '
                'you can analyze data.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.pushNamed(context, AppRoutes.generalSettings);
          },
          child: const Text('Open settings'),
        ),
      ],
    ),
  );

  return false;
}

Future<void> launchMonthlyInsightsAnalysis(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!await ensureAnalysisFolder(context, ref) || !context.mounted) return;
  if (!await ensurePersonalInformation(context, ref) || !context.mounted) {
    return;
  }

  final selection = await showAnalysisConfirmDialog(context: context, ref: ref);
  if (selection == null || !context.mounted) return;

  final result =
      await ref.read(analysisRunProvider.notifier).runAnalysis(selection);
  if (!context.mounted) return;

  if (result == null) {
    final error = ref.read(analysisRunProvider).lastError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ResultDetailScreen(result: result),
    ),
  );
}

Future<void> launchProgressReviewAnalysis(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!await ensureAnalysisFolder(context, ref) || !context.mounted) return;
  if (!await ensurePersonalInformation(context, ref) || !context.mounted) {
    return;
  }

  final checklistSource = resolveChecklistSource(ref);
  if (checklistSource == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Run a monthly analysis first to generate a checklist.',
        ),
      ),
    );
    return;
  }

  final request = await showProgressConfirmDialog(
    context: context,
    ref: ref,
    checklistSource: checklistSource,
  );
  if (request == null || !context.mounted) return;

  final result = await ref.read(analysisRunProvider.notifier).runProgressReview(
        selection: request.selection,
        checklistSource: request.checklistSource,
      );
  if (!context.mounted) return;

  if (result == null) {
    final error = ref.read(analysisRunProvider).lastError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ResultDetailScreen(result: result),
    ),
  );
}
