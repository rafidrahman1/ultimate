import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/features/home/analysis_confirm_preferences_service.dart';
import 'package:personal/features/home/analysis_data_preview.dart';

/// Shows which sources and period will be sent to monthly analysis.
/// Returns the user's source selection, or null if cancelled.
Future<AnalysisSourceSelection?> showAnalysisConfirmDialog({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final period = ref.read(analysisPeriodProvider);
  final expenses = ref.read(expensesForAnalysisProvider);
  final location = ref.read(locationForAnalysisProvider);
  final gameActivity = ref.read(gameActivityForAnalysisProvider);
  final calendar = ref.read(calendarForAnalysisProvider);
  final calendarUpcoming = ref.read(calendarForDisplayProvider);
  final healthAsync = ref.read(monthlyHealthDataProvider);
  final aiSettings = await ref.read(aiSettingsProvider.future);
  final promptConfig = await ref.read(promptConfigProvider.future);

  final insightEngineLabel = aiSettings.enableApiCalls
      ? 'Cloud AI (${aiSettings.provider.name} · '
          '${aiSettings.provider == AiProvider.openai ? aiSettings.openAiModel : aiSettings.geminiModel})'
      : 'On-device summary (no API call)';

  if (!context.mounted) return null;

  final preview = buildAnalysisRunPreview(
    period: period,
    healthFetch: healthAsync.valueOrNull,
    healthLoading: healthAsync.isLoading,
    expenses: expenses,
    location: location,
    gameActivity: gameActivity,
    calendar: calendar,
    calendarUpcomingSource: calendarUpcoming,
    insightEngineLabel: insightEngineLabel,
    workAddress: promptConfig.workAddress,
    workHours: promptConfig.workHours,
    weekendDays: promptConfig.weekendDays,
  );

  final saved = await ref
      .read(analysisConfirmPreferencesProvider.notifier)
      .resolveForPreview(preview);

  if (!context.mounted) return null;

  return showDialog<AnalysisSourceSelection>(
    context: context,
    builder: (dialogContext) => _AnalysisConfirmDialog(
      preview: preview,
      initialPromptOverrides: saved.promptOverrides,
      initialIncluded: saved.included,
    ),
  );
}

class _AnalysisConfirmDialog extends ConsumerStatefulWidget {
  const _AnalysisConfirmDialog({
    required this.preview,
    required this.initialPromptOverrides,
    this.initialIncluded,
  });

  final AnalysisRunPreview preview;
  final Map<AnalysisDataSourceId, String> initialPromptOverrides;
  final Set<AnalysisDataSourceId>? initialIncluded;

  @override
  ConsumerState<_AnalysisConfirmDialog> createState() =>
      _AnalysisConfirmDialogState();
}

class _AnalysisConfirmDialogState
    extends ConsumerState<_AnalysisConfirmDialog> {
  late Set<AnalysisDataSourceId> _included;
  late Map<AnalysisDataSourceId, String> _promptOverrides;

  @override
  void initState() {
    super.initState();
    _promptOverrides = Map.of(widget.initialPromptOverrides);
    _included = widget.initialIncluded ??
        {
          for (final source in widget.preview.sources)
            if (source.hasData) source.id,
        };
  }

  void _toggle(AnalysisDataSourceId id, bool? checked) {
    setState(() {
      if (checked == true) {
        _included.add(id);
      } else {
        _included.remove(id);
      }
    });
    unawaited(
      ref.read(analysisConfirmPreferencesProvider.notifier).saveIncluded(
            periodStart: widget.preview.period.dataMonthStart,
            included: _included,
          ),
    );
  }

  Future<void> _editSourcePrompt(AnalysisDataSourcePreview source) async {
    final original = source.promptText;
    final controller =
        TextEditingController(text: _promptOverrides[source.id] ?? original);
    final edited = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(source.label),
        content: TextField(
          controller: controller,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, original),
            child: const Text('Reset'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || edited == null) return;

    final notifier = ref.read(analysisConfirmPreferencesProvider.notifier);
    setState(() {
      if (edited == original) {
        _promptOverrides.remove(source.id);
      } else {
        _promptOverrides[source.id] = edited;
      }
    });

    if (edited == original) {
      unawaited(
        notifier.clearPromptOverride(
          periodStart: widget.preview.period.dataMonthStart,
          sourceId: source.id,
        ),
      );
    } else {
      unawaited(
        notifier.savePromptOverride(
          preview: widget.preview,
          sourceId: source.id,
          basePromptText: original,
          overrideText: edited,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.preview;
    final monthLabel =
        DateFormat('MMMM yyyy').format(preview.period.dataMonthStart);
    final canRun = !preview.healthLoading && _included.isNotEmpty;

    return AlertDialog(
      title: const Text('Confirm data to analyze'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Analysis month: $monthLabel',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Data window: ${preview.period.dataRangeLabel}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Include in this run',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Uncheck any source to leave it out of the prompt.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final source in preview.sources)
              _SourceCheckboxRow(
                source: source,
                included: _included.contains(source.id),
                onChanged: (checked) => _toggle(source.id, checked),
                onLongPress: () => _editSourcePrompt(source),
              ),
            const SizedBox(height: 12),
            Text(
              preview.insightEngineLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_included.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Select at least one source to run analysis.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ] else if (!preview.hasAnyData &&
                !preview.healthLoading &&
                !_included.any(
                  (id) => preview.sources
                      .firstWhere((s) => s.id == id)
                      .hasData,
                )) ...[
              const SizedBox(height: 12),
              Text(
                'Selected sources have no loaded data. Insights will be limited.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canRun
              ? () => Navigator.pop(
                    context,
                    AnalysisSourceSelection(
                      Set.from(_included),
                      promptOverrides: _promptOverrides,
                    ),
                  )
              : null,
          child: const Text('Run analysis'),
        ),
      ],
    );
  }
}

class _SourceCheckboxRow extends StatelessWidget {
  const _SourceCheckboxRow({
    required this.source,
    required this.included,
    required this.onChanged,
    required this.onLongPress,
  });

  final AnalysisDataSourcePreview source;
  final bool included;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = !included;

    return GestureDetector(
      onLongPress: onLongPress,
      behavior: HitTestBehavior.deferToChild,
      child: CheckboxListTile(
        value: included,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        dense: true,
        secondary: Icon(
          source.icon,
          size: 20,
          color: analysisSourceColor(context, source.id),
        ),
        title: Text(
          source.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: muted ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              source.detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
            if (source.note != null)
              Text(
                source.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
