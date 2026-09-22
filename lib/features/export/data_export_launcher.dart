import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_launcher.dart';
import 'package:personal/features/export/ai_curation_choice_dialog.dart';
import 'package:personal/features/export/data_export_service.dart';
import 'package:personal/features/export/data_export_storage.dart';
import 'package:personal/features/export/export_curation_service.dart';
import 'package:personal/features/home/analysis_confirm_dialog.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

Future<void> launchDataExport(BuildContext context, WidgetRef ref) async {
  if (!await ensureAnalysisFolder(context, ref) || !context.mounted) return;

  final selection = await showAnalysisConfirmDialog(
    context: context,
    ref: ref,
    title: 'Confirm data to export',
    confirmLabel: 'Export',
  );
  if (selection == null || !context.mounted) return;

  final aiSettings = await ref.read(aiSettingsProvider.future);
  if (!context.mounted) return;

  var curate = false;
  if (aiSettings.enableApiCalls) {
    final choice = await showAiCurationChoiceDialog(context);
    if (choice == null || !context.mounted) return;
    curate = choice;
  }

  try {
    final service = ref.read(dataExportServiceProvider);
    final raw = await service.buildRawMarkdown(selection);

    var markdown = raw.markdown;
    if (curate) {
      try {
        markdown = await curateExportMarkdown(
          aiSettings: aiSettings,
          rawMarkdown: raw.markdown,
          period: raw.period,
        );
      } catch (error) {
        markdown = raw.markdown;
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'AI curation failed ($error). Saved raw data instead.',
            ),
          ),
        );
      }
    }

    final file = await DataExportStorage.instance.save(
      markdown,
      generatedAt: DateTime.now(),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved export to ${file.path}')));
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not save export: $error')));
  }
}
