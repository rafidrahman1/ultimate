import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../core/analysis_kind.dart';
import 'analysis_launcher.dart';
import '../results/analysis_service.dart';
import '../results/results_service.dart';
import '../results/results_settings_service.dart';
import '../results/selected_checklist_result_service.dart';

class AnalyzeScreen extends ConsumerWidget {
  const AnalyzeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(analysisRunProvider);
    final settings = ref.watch(resultsSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;
    final results = ref.watch(analysisResultsProvider).valueOrNull ?? [];
    final withChecklist = analysisResultsWithChecklist(results);
    final selectedChecklistId = ref.watch(selectedChecklistResultIdProvider);
    final checklistSourceId = resolveSelectedChecklistResultId(
      withChecklist: withChecklist,
      storedId: selectedChecklistId,
    );
    final checklistSource = checklistSourceId == null
        ? null
        : withChecklist.firstWhere((r) => r.id == checklistSourceId);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        bottomInset + extraBottomForNavPill,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasFolder) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.folder_off_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Report save folder required',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                needsReselect
                                    ? 'Re-select your report save folder in Results settings '
                                          'so Android can write files there.'
                                    : 'Choose a report save folder in Results settings before '
                                          'you can analyze data.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.resultsSettings,
                        ),
                        child: const Text('Open settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: runState.isRunning || !hasFolder
                    ? null
                    : () => launchMonthlyInsightsAnalysis(context, ref),
                icon: runState.isRunning
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(
                  runState.isRunning
                      ? 'Running...'
                      : AnalysisKind.monthlyInsights.displayName,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: runState.isRunning ||
                        !hasFolder ||
                        checklistSource == null
                    ? null
                    : () => launchProgressReviewAnalysis(context, ref),
                icon: const Icon(Icons.trending_up_outlined),
                label: Text(AnalysisKind.progressReview.displayName),
              ),
              if (checklistSource == null && hasFolder) ...[
                const SizedBox(height: 8),
                Text(
                  'Run a monthly analysis first to generate a checklist, '
                  'then review progress here.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
