import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/results/analysis_service.dart';

/// Shows what the running analysis is doing, with a cancel button.
/// Closes itself when the run finishes.
Future<void> showAnalysisProgressSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _AnalysisProgressSheet(),
  );
}

class _AnalysisProgressSheet extends ConsumerStatefulWidget {
  const _AnalysisProgressSheet();

  @override
  ConsumerState<_AnalysisProgressSheet> createState() =>
      _AnalysisProgressSheetState();
}

class _AnalysisProgressSheetState
    extends ConsumerState<_AnalysisProgressSheet> {
  late final Timer _ticker;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    // Refresh the elapsed-time label.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(analysisRunProvider);
    ref.listen(analysisRunProvider.select((state) => state.isRunning), (
      _,
      running,
    ) {
      if (!running && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    final theme = Theme.of(context);
    final stages = AnalysisStage.values;
    final currentIndex = run.stage == null ? -1 : stages.indexOf(run.stage!);
    final elapsed = run.startedAt == null
        ? Duration.zero
        : DateTime.now().difference(run.startedAt!);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Analysis in progress',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Elapsed ${_formatElapsed(elapsed)} · keep Personal open',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < stages.length; i++)
              _StageRow(
                label: stages[i].label,
                status: i < currentIndex
                    ? _StageStatus.done
                    : i == currentIndex
                    ? _StageStatus.active
                    : _StageStatus.pending,
              ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: !run.isRunning || _cancelling
                  ? null
                  : () {
                      setState(() => _cancelling = true);
                      ref.read(analysisRunProvider.notifier).cancel();
                    },
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(_cancelling ? 'Cancelling…' : 'Cancel analysis'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatElapsed(Duration elapsed) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

enum _StageStatus { done, active, pending }

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.status});

  final String label;
  final _StageStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusText = switch (status) {
      _StageStatus.done => 'done',
      _StageStatus.active => 'in progress',
      _StageStatus.pending => 'pending',
    };

    return Semantics(
      label: '$label, $statusText',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 20,
              child: switch (status) {
                _StageStatus.done => Icon(
                  Icons.check_circle,
                  size: 20,
                  color: colorScheme.primary,
                ),
                _StageStatus.active => const CircularProgressIndicator(
                  strokeWidth: 2.5,
                ),
                _StageStatus.pending => Icon(
                  Icons.radio_button_unchecked,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: status == _StageStatus.active
                      ? FontWeight.w700
                      : FontWeight.w400,
                  color: status == _StageStatus.pending
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
