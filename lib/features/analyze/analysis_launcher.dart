import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../home/analysis_confirm_dialog.dart';
import '../home/progress_confirm_dialog.dart';
import '../results/analysis_service.dart';
import '../results/result_detail_screen.dart';
import '../results/results_service.dart';
import '../results/results_settings_service.dart';
import '../results/selected_checklist_result_service.dart';

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

Future<bool> ensureAnalysisFolder(BuildContext context, WidgetRef ref) async {
  final settings = ref.read(resultsSettingsProvider).valueOrNull;
  final hasFolder = settings?.hasFolder ?? false;
  if (hasFolder) return true;

  final needsReselect = settings?.needsReselect ?? false;
  if (!context.mounted) return false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Report save folder required'),
      content: Text(
        needsReselect
            ? 'Re-select your report save folder in Results settings '
                'so Android can write files there.'
            : 'Choose a report save folder in Results settings before '
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
            Navigator.pushNamed(context, AppRoutes.resultsSettings);
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
