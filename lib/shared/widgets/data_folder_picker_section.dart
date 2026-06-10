import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/shared/widgets/section_header.dart';
import 'package:personal/shared/widgets/status_message.dart';

class DataFolderPickerSection extends ConsumerWidget {
  const DataFolderPickerSection({
    super.key,
    this.onFolderChanged,
  });

  final VoidCallback? onFolderChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(dataFolderSettingsProvider);
    final theme = Theme.of(context);

    return settingsAsync.when(
      data: (settings) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            'Data folder',
            subtitle:
                'Choose one folder for Cashew exports, Timeline exports, Game Activity CSVs, '
                'and saved analysis reports. Everything lives in the same place.',
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            onPressed: () => _pickFolder(context, ref),
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose folder'),
          ),
          if (settings.hasFolder || settings.needsReselect) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _clearFolder(context, ref),
              icon: const Icon(Icons.clear),
              label: const Text('Clear folder'),
            ),
          ],
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatusMessage(
        icon: Icons.error_outline,
        title: 'Could not load data folder settings',
        subtitle: error.toString(),
      ),
    );
  }

  Future<void> _pickFolder(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final location = await DirPicker.pick(
      options: PickOptions.android(shouldPersist: true),
    );
    if (location == null) return;

    await ref.read(dataFolderSettingsProvider.notifier).saveFolder(location);
    onFolderChanged?.call();
    messenger.showSnackBar(
      const SnackBar(content: Text('Data folder saved')),
    );
  }

  Future<void> _clearFolder(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(dataFolderSettingsProvider.notifier).clearFolder();
    onFolderChanged?.call();
    messenger.showSnackBar(
      const SnackBar(content: Text('Data folder cleared')),
    );
  }
}
