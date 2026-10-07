import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/prediction_selection_service.dart';

/// Opens the sheet where the user ticks which predictions to show. Switched-off
/// predictions are not calculated, listed, or sent to an AI provider.
Future<void> showPredictionChooser(
  BuildContext context, {
  required Set<String> shownKeys,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => PredictionChooser(shownKeys: shownKeys),
  );
}

class PredictionChooser extends ConsumerWidget {
  const PredictionChooser({super.key, required this.shownKeys});

  /// Keys currently on the dashboard, to tell "on but no data yet" apart.
  final Set<String> shownKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final off = ref.watch(predictionDisabledProvider);
    final notifier = ref.read(predictionDisabledProvider.notifier);
    final total = allPredictionOptions.length;
    final onCount = total - off.length.clamp(0, total);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screen,
          0,
          AppSpacing.screen,
          AppSpacing.screen + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Choose predictions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: onCount == total
                    ? null
                    : () => notifier.setAllEnabled(true),
                child: const Text('All'),
              ),
              TextButton(
                onPressed: onCount == 0
                    ? null
                    : () => notifier.setAllEnabled(false),
                child: const Text('None'),
              ),
            ],
          ),
          Text(
            '$onCount of $total on. Predictions that are off are not '
            'calculated or sent to your AI provider. Some need more history '
            'before they appear.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.textMuted,
            ),
          ),
          for (final group in PredictionGroup.values) ...[
            const SizedBox(height: AppSpacing.lg),
            _GroupHeader(group: group, off: off, notifier: notifier),
            for (final option in allPredictionOptions.where(
              (o) => o.group == group,
            ))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: !off.contains(option.key),
                onChanged: (v) => notifier.setEnabled(option.key, v),
                title: Text(option.label),
                subtitle: Text(
                  !off.contains(option.key) && !shownKeys.contains(option.key)
                      ? '${option.blurb} · not enough data yet'
                      : option.blurb,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.off,
    required this.notifier,
  });

  final PredictionGroup group;
  final Set<String> off;
  final PredictionDisabledNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final keys = [
      for (final o in allPredictionOptions)
        if (o.group == group) o.key,
    ];
    final allOn = keys.every((k) => !off.contains(k));
    return Row(
      children: [
        Expanded(
          child: Text(group.label.toUpperCase(), style: context.sectionLabel),
        ),
        TextButton(
          onPressed: () => notifier.setGroupEnabled(group, !allOn),
          child: Text(allOn ? 'Turn off group' : 'Turn on group'),
        ),
      ],
    );
  }
}
