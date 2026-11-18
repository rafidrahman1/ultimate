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
            fontWeight: FontWeight.w700,
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
