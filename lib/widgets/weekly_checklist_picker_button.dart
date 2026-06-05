import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/results/results_service.dart';
import '../features/results/selected_checklist_result_service.dart';
import 'circular_app_bar_button.dart';

class WeeklyChecklistPickerButton extends ConsumerWidget {
  const WeeklyChecklistPickerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(analysisResultsProvider);
    final storedId = ref.watch(selectedChecklistResultIdProvider);

    return resultsAsync.when(
      data: (results) {
        final withChecklist = analysisResultsWithChecklist(results);
        if (withChecklist.isEmpty) return const SizedBox.shrink();

        final selectedId = resolveSelectedChecklistResultId(
          withChecklist: withChecklist,
          storedId: storedId,
        );
        if (selectedId == null) return const SizedBox.shrink();

        final dateFormat = DateFormat('d MMM yyyy · HH:mm');

        return CircularAppBarButton(
          icon: Icons.swap_horiz_rounded,
          onPressed: () => _showPicker(
            context,
            ref,
            withChecklist: withChecklist,
            selectedId: selectedId,
            dateFormat: dateFormat,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref, {
    required List<AnalysisResult> withChecklist,
    required String selectedId,
    required DateFormat dateFormat,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Text(
                  'Choose checklist',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              for (final result in withChecklist)
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: result.id == selectedId,
                  title: Text(result.title),
                  subtitle: Text(
                    dateFormat.format(result.createdAt.toLocal()),
                  ),
                  trailing: result.id == selectedId
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, result.id),
                ),
            ],
          ),
        );
      },
    );

    if (selected == null || !context.mounted) return;
    await ref.read(selectedChecklistResultIdProvider.notifier).select(selected);
  }
}
