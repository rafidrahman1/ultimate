import 'package:flutter/material.dart';

/// Asks whether the export should be sent to the configured AI provider for
/// curation. Returns `true` to curate, `false` for raw data only, or `null`
/// if the user cancelled the export entirely.
Future<bool?> showAiCurationChoiceDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Curate with AI?'),
      content: const Text(
        'Send this data to your configured AI provider to rewrite it into a '
        'cleaner summary before saving? This uses your AI settings and '
        'counts against your API usage. Choose "Raw data only" to skip the '
        'API call and save the data as-is.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Raw data only'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Curate with AI'),
        ),
      ],
    ),
  );
}
