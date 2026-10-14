import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/ui/weekly_verify_confirm_dialog.dart';
import 'package:personal/features/results/checklist/insight_checklist_service.dart';
import 'package:personal/features/results/checklist/weekly_checklist_verification_prompt.dart';
import 'package:personal/features/results/pipeline/analysis_service.dart';
import 'package:personal/features/results/reports/insights_models.dart';
import 'package:personal/features/results/reports/results_service.dart';
import 'package:personal/features/results/ui/insights_dashboard.dart';
import 'package:personal/shared/widgets/app_card.dart';

part 'weekly_checklist_widgets.dart';

/// Weekly pager for the monthly action checklist with persisted check state.
class WeeklyChecklistPanel extends ConsumerStatefulWidget {
  const WeeklyChecklistPanel({
    super.key,
    required this.resultId,
    this.checklistSource,
    required this.period,
    required this.report,
    required this.monthLabel,
  });

  final String resultId;
  final AnalysisResult? checklistSource;
  final AnalysisPeriod period;
  final InsightsParsedReport report;
  final String monthLabel;

  @override
  ConsumerState<WeeklyChecklistPanel> createState() =>
      _WeeklyChecklistPanelState();
}

class _WeeklyChecklistPanelState extends ConsumerState<WeeklyChecklistPanel> {
  late int _weekIndex;

  @override
  void initState() {
    super.initState();
    _weekIndex = resolveDefaultChecklistWeekIndex(
      period: widget.period,
      weekCount: _weekCount,
      today: DateTime.now(),
    );
  }

  int get _weekCount {
    return math.max(
      widget.report.checklistWeekCount,
      widget.period.checklistWeekCount,
    );
  }

  String _weekRangeLabel(int index) {
    if (index < widget.period.checklistWeeks.length) {
      final week = widget.period.checklistWeeks[index];
      return formatCompactPeriodRange(week.start, week.end);
    }
    return '';
  }

  List<ActionDirective> _actionsForWeek(int index) =>
      widget.report.actionsForWeekIndex(index);

  /// Index of the checklist week containing today, or null outside the month.
  int? _currentWeekIndex() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weeks = widget.period.checklistWeeks;
    for (var i = 0; i < weeks.length; i++) {
      final start = weeks[i].start;
      final end = weeks[i].end;
      if (!today.isBefore(DateTime(start.year, start.month, start.day)) &&
          !today.isAfter(DateTime(end.year, end.month, end.day))) {
        return i;
      }
    }
    return null;
  }

  ({int done, int total}) _weekProgress(int index) {
    final state = ref
        .watch(
          insightChecklistProvider(
            insightChecklistStorageKey(widget.resultId, index),
          ),
        )
        .valueOrNull;
    return (
      done: state?.completed.length ?? 0,
      total: _actionsForWeek(index).length,
    );
  }

  ({int done, int total}) _monthProgress() {
    var done = 0;
    var total = 0;
    for (var i = 0; i < _weekCount; i++) {
      final week = _weekProgress(i);
      done += week.done;
      total += week.total;
    }
    return (done: done, total: total);
  }

  /// Consecutive fully completed weeks ending at the current (or last
  /// started) week; the current week only counts once it is complete.
  int _streak() {
    final current = _currentWeekIndex() ?? (_weekCount - 1);
    var streak = 0;
    for (var i = current; i >= 0; i--) {
      final week = _weekProgress(i);
      final complete = week.total > 0 && week.done >= week.total;
      if (complete) {
        streak++;
      } else if (i != current) {
        break;
      }
    }
    return streak;
  }

  Future<void> _editNote(
    BuildContext context,
    String storageKey,
    int index,
    String? existing,
  ) async {
    final controller = TextEditingController(text: existing ?? '');
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Note'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Why it slipped, what helped, a reminder...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null) return;
    await ref
        .read(insightChecklistProvider(storageKey).notifier)
        .setNote(index, text);
  }

  void _goToWeek(int index) {
    if (index < 0 || index >= _weekCount || index == _weekIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _weekIndex = index);
  }

  String? _weekThemeLabel(int index) => widget.report.themeForWeekIndex(index);

  String _weekHeaderLabel(int index) => buildWeekHeaderLabel(
    checklistPeriod: widget.period,
    weekIndex: index,
    report: widget.report,
  );

  Future<void> _verifyWeek() async {
    final source = widget.checklistSource;
    if (source == null) return;
    final weekActions = _actionsForWeek(_weekIndex);
    if (weekActions.isEmpty) return;

    final request = await showWeeklyVerifyConfirmDialog(
      context: context,
      ref: ref,
      checklistSource: source,
      weekIndex: _weekIndex,
      report: widget.report,
      weekHeader: _weekHeaderLabel(_weekIndex),
      actionCount: weekActions.length,
    );
    if (request == null || !mounted) return;

    final result = await ref
        .read(analysisRunProvider.notifier)
        .verifyWeeklyChecklist(
          selection: request.selection,
          checklistSource: request.checklistSource,
          weekIndex: request.weekIndex,
        );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (result == null) {
      final error = ref.read(analysisRunProvider).lastError;
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? 'Verification failed')),
      );
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${result.completedCount} met · ${result.failedCount} failed · '
          '${result.unverifiedCount} unverified',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_weekCount == 0 || widget.report.actions.isEmpty) {
      return const SizedBox.shrink();
    }

    final storageKey = insightChecklistStorageKey(widget.resultId, _weekIndex);
    final weekStateAsync = ref.watch(insightChecklistProvider(storageKey));
    final weekActions = _actionsForWeek(_weekIndex);
    final weekState = weekStateAsync.valueOrNull ?? WeekChecklistState.empty;
    final isRunning = ref.watch(
      analysisRunProvider.select((state) => state.isRunning),
    );

    // Celebrate when the last open item of the week gets ticked.
    ref.listen(insightChecklistProvider(storageKey), (previous, next) {
      final total = weekActions.length;
      final before = previous?.valueOrNull?.completed.length ?? 0;
      final after = next.valueOrNull?.completed.length ?? 0;
      if (total > 0 && before < total && after >= total) {
        HapticFeedback.heavyImpact();
      }
    });

    final month = _monthProgress();
    final streak = _streak();
    final currentIndex = _currentWeekIndex();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 300) return;
        _goToWeek(velocity < 0 ? _weekIndex + 1 : _weekIndex - 1);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (month.total > 0) ...[
            _MonthSummary(
              monthLabel: widget.monthLabel,
              done: month.done,
              total: month.total,
              streak: streak,
            ),
            const SizedBox(height: 14),
          ],
          _WeekPillBar(
            weekCount: _weekCount,
            selectedIndex: _weekIndex,
            currentIndex: _currentWeekIndex(),
            rangeLabelFor: _weekRangeLabel,
            progressFor: _weekProgress,
            onSelected: _goToWeek,
          ),
          if (currentIndex != null && currentIndex != _weekIndex)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _goToWeek(currentIndex),
                icon: const Icon(Icons.today_rounded, size: 18),
                label: const Text('Jump to this week'),
              ),
            ),
          if (_weekThemeLabel(_weekIndex) != null) ...[
            const SizedBox(height: 10),
            _WeekThemeChip(theme: _weekThemeLabel(_weekIndex)!),
          ],
          const SizedBox(height: 14),
          if (weekActions.isNotEmpty && widget.checklistSource != null) ...[
            FilledButton.tonalIcon(
              onPressed: isRunning ? null : _verifyWeek,
              icon: isRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined, size: 20),
              label: const Text('Verify week'),
            ),
            const SizedBox(height: 6),
            Text(
              weekState.verifiedAt == null
                  ? 'Not verified yet. Checks this week\'s actions against '
                        'your loaded data and marks each as met or failed.'
                  : 'Last verified ${relativeTime(weekState.verifiedAt!)}. '
                        'Re-run to refresh results.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
            ),
            const SizedBox(height: 14),
          ],
          if (weekActions.isNotEmpty) ...[
            _WeekProgressBar(
              done: weekState.completed.length,
              total: weekActions.length,
            ),
            const SizedBox(height: 14),
          ],
          if (weekActions.isEmpty)
            Text(
              'No actions for this week in the latest analysis.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
            )
          else
            AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              child: KeyedSubtree(
                key: ValueKey(_weekIndex),
                child: InsightsGroupedActionList(
                  directives: weekActions,
                  weekState: weekState,
                  onToggle: (index) {
                    HapticFeedback.lightImpact();
                    ref
                        .read(insightChecklistProvider(storageKey).notifier)
                        .toggle(index);
                  },
                  onEditNote: (index) => _editNote(
                    context,
                    storageKey,
                    index,
                    weekState.notes[index],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
