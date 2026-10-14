part of 'location_panels.dart';

/// Shown when no Timeline file is found: where the export comes from.
class TimelineExportHelp extends StatelessWidget {
  const TimelineExportHelp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    const steps = [
      'Open Google Maps, tap your profile picture, then Settings.',
      'Choose Your Timeline (or Location and Timeline).',
      'Tap Export Timeline data and save it into your Personal data folder.',
      'Come back here and tap Reload (or pull down).',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to export your Timeline',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              '${i + 1}. ${steps[i]}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Name a place. Returns the entered text ('' to clear), or null if cancelled.
Future<String?> showRenamePlaceDialog(
  BuildContext context, {
  required String current,
  required String fallback,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _RenamePlaceDialog(current: current, fallback: fallback),
  );
}

class _RenamePlaceDialog extends StatefulWidget {
  const _RenamePlaceDialog({required this.current, required this.fallback});

  final String current;
  final String fallback;

  @override
  State<_RenamePlaceDialog> createState() => _RenamePlaceDialogState();
}

class _RenamePlaceDialogState extends State<_RenamePlaceDialog> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name this place'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        decoration: InputDecoration(
          hintText: widget.fallback,
          helperText: 'Included in analysis once named.',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        if (widget.current.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Opens [place] in the device's map app.
Future<void> openPlaceOnMap(
  BuildContext context,
  PlaceStat place,
  String label,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final point = place.point;
  if (point == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No location recorded for this place.')),
    );
    return;
  }
  final coords = '${point.latitude},${point.longitude}';
  final uris = [
    Uri.parse('geo:$coords?q=$coords(${Uri.encodeComponent(label)})'),
    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': coords}),
  ];
  for (final uri in uris) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Try the next option.
    }
  }
  messenger.showSnackBar(
    const SnackBar(content: Text('Could not open a maps app.')),
  );
}
