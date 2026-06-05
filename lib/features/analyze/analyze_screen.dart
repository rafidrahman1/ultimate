import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/analysis_confirm_dialog.dart';
import '../results/analysis_service.dart';
import '../results/results_screen.dart';
import '../results/results_service.dart';
import '../results/selected_checklist_result_service.dart';

Future<void> confirmClearAllAnalysisResults(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear all results?'),
      content: const Text(
        'This removes your saved insight history from this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  await ref.read(analysisResultsProvider.notifier).clearAll();
  await ref.read(selectedChecklistResultIdProvider.notifier).clear();
}

class AnalyzeScreen extends ConsumerWidget {
  const AnalyzeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runState = ref.watch(analysisRunProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: FilledButton.icon(
            onPressed: runState.isRunning
                ? null
                : () async {
                    final selection = await showAnalysisConfirmDialog(
                      context: context,
                      ref: ref,
                    );
                    if (selection == null || !context.mounted) return;

                    await ref
                        .read(analysisRunProvider.notifier)
                        .runAnalysis(selection);
                    if (!context.mounted) return;
                    final latest = ref.read(analysisRunProvider);
                    if (latest.lastError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(latest.lastError!)),
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Analysis completed and saved'),
                      ),
                    );
                  },
            icon: runState.isRunning
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.analytics_outlined),
            label: Text(
              runState.isRunning ? 'Analyzing...' : 'Analyze data',
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset + extraBottomForNavPill),
            child: const ResultsScreen(embedded: true),
          ),
        ),
      ],
    );
  }
}
