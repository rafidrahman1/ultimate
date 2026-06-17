import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/home/analysis_confirm_context.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/results_service.dart';

class WeeklyVerifyRequest {
  const WeeklyVerifyRequest({
    required this.selection,
    required this.checklistSource,
    required this.weekIndex,
  });

  final AnalysisSourceSelection selection;
  final AnalysisResult checklistSource;
  final int weekIndex;
}

/// Confirms data sources before verifying the current checklist week.
Future<WeeklyVerifyRequest?> showWeeklyVerifyConfirmDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AnalysisResult checklistSource,
  required int weekIndex,
  required InsightsParsedReport report,
  required String weekHeader,
  required int actionCount,
}) async {
  final preview = await loadAnalysisRunPreview(
    ref,
    context,
    onDeviceInsightLabel: 'On-device summary (marks all items Unverified)',
  );
  if (preview == null) return null;
  if (!context.mounted) return null;

  return showDialog<WeeklyVerifyRequest>(
    context: context,
    builder: (dialogContext) => _WeeklyVerifyConfirmDialog(
      preview: preview,
      checklistSource: checklistSource,
      weekIndex: weekIndex,
      weekHeader: weekHeader,
      actionCount: actionCount,
    ),
  );
}

class _WeeklyVerifyConfirmDialog extends StatefulWidget {
  const _WeeklyVerifyConfirmDialog({
    required this.preview,
    required this.checklistSource,
    required this.weekIndex,
    required this.weekHeader,
    required this.actionCount,
  });

  final AnalysisRunPreview preview;
  final AnalysisResult checklistSource;
  final int weekIndex;
  final String weekHeader;
  final int actionCount;

  @override
  State<_WeeklyVerifyConfirmDialog> createState() =>
      _WeeklyVerifyConfirmDialogState();
}

class _WeeklyVerifyConfirmDialogState extends State<_WeeklyVerifyConfirmDialog> {
  late final Set<AnalysisDataSourceId> _included = {
    for (final source in widget.preview.sources)
      if (source.hasData) source.id,
  };

  void _toggle(AnalysisDataSourceId id, bool? checked) {
    setState(() {
      if (checked == true) {
        _included.add(id);
      } else {
        _included.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = widget.preview;
    final canRun = !preview.healthLoading && _included.isNotEmpty;

    return AlertDialog(
      title: const Text('Verify checklist week'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Compare this week\'s checklist targets against your data. '
              'Items will be marked complete or failed based on the review.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              widget.weekHeader,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${widget.actionCount} action(s) · ${widget.checklistSource.title}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Include in this run',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final source in preview.sources)
              _SourceCheckboxRow(
                source: source,
                included: _included.contains(source.id),
                onChanged: (checked) => _toggle(source.id, checked),
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
                'Select at least one source to verify.',
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
                    WeeklyVerifyRequest(
                      selection: AnalysisSourceSelection(Set.from(_included)),
                      checklistSource: widget.checklistSource,
                      weekIndex: widget.weekIndex,
                    ),
                  )
              : null,
          child: const Text('Verify week'),
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
  });

  final AnalysisDataSourcePreview source;
  final bool included;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = !included;

    return CheckboxListTile(
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
      subtitle: Text(
        source.detail,
        style: theme.textTheme.bodySmall?.copyWith(
          color: muted ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
    );
  }
}
