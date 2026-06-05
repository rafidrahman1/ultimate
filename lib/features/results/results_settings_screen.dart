import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_reports_storage.dart';
import '../../widgets/app_screen_app_bar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_message.dart';
import 'results_service.dart';
import 'results_settings_service.dart';

class ResultsSettingsScreen extends ConsumerWidget {
  const ResultsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(resultsSettingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Results settings'),
      body: settingsAsync.when(
        data: (settings) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(
              'Report save folder',
              subtitle:
                  'Choose where analysis reports are saved as JSON files. '
                  'Analysis is disabled until a folder is selected.',
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: Icon(
                  Icons.folder_outlined,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  settings.hasFolder
                      ? 'Folder selected'
                      : settings.needsReselect
                      ? 'Re-select folder required'
                      : 'No folder selected',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  settings.needsReselect
                      ? '${settings.displayLabel}\n'
                            'Android needs folder access again. Choose the same folder once.'
                      : settings.displayLabel,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final location = await DirPicker.pick(
                  options: PickOptions.android(shouldPersist: true),
                );
                if (location == null) return;

                await ref
                    .read(resultsSettingsProvider.notifier)
                    .saveFolder(location);
                AnalysisReportsStorage.instance.invalidateCache();
                ref.invalidate(analysisResultsProvider);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Report save folder saved')),
                );
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Choose folder'),
            ),
            if (settings.hasFolder || settings.needsReselect) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref.read(resultsSettingsProvider.notifier).clearFolder();
                  AnalysisReportsStorage.instance.invalidateCache();
                  ref.invalidate(analysisResultsProvider);
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Report save folder cleared')),
                  );
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear folder'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Saved files use the name analysis-report-<id>.json',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load results settings',
          subtitle: error.toString(),
        ),
      ),
    );
  }
}
