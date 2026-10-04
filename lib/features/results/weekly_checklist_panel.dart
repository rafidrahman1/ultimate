import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/core/period_range.dart';
import 'package:personal/features/home/weekly_verify_confirm_dialog.dart';
import 'package:personal/features/results/analysis_service.dart';
import 'package:personal/features/results/insight_checklist_service.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/results/insights_dashboard.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/features/results/weekly_checklist_verification_prompt.dart';
import 'package:personal/shared/widgets/app_card.dart';

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
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({
    required this.monthLabel,
    required this.done,
    required this.total,
    required this.streak,
  });

  final String monthLabel;
  final int done;
  final int total;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final fraction = total == 0 ? 0.0 : done / total;

    return Semantics(
      label:
          '$monthLabel plan: $done of $total actions done'
          '${streak > 0 ? ', $streak week streak' : ''}',
      excludeSemantics: true,
      child: AppCard(
        tier: AppCardTier.hero,
        accent: palette.statusGood,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTH PROGRESS', style: context.sectionLabel),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${(fraction * 100).round()}%',
                    style: context.statDisplay.copyWith(
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$done of $total actions',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (streak > 0)
              Column(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: palette.warning,
                    size: 28,
                  ),
                  Text(
                    '$streak ${streak == 1 ? 'week' : 'weeks'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text('streak', style: theme.textTheme.labelSmall),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekPillBar extends StatelessWidget {
  const _WeekPillBar({
    required this.weekCount,
    required this.selectedIndex,
    required this.currentIndex,
    required this.rangeLabelFor,
    required this.progressFor,
    required this.onSelected,
  });

  final int weekCount;
  final int selectedIndex;
  final int? currentIndex;
  final String Function(int index) rangeLabelFor;
  final ({int done, int total}) Function(int index) progressFor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < weekCount; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            _WeekPill(
              weekLabel: 'Week ${i + 1}',
              rangeLabel: rangeLabelFor(i),
              progress: progressFor(i),
              isCurrent: i == currentIndex,
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekPill extends StatelessWidget {
  const _WeekPill({
    required this.weekLabel,
    required this.rangeLabel,
    required this.progress,
    required this.isCurrent,
    required this.selected,
    required this.onTap,
  });

  final String weekLabel;
  final String rangeLabel;
  final ({int done, int total}) progress;
  final bool isCurrent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.palette.accent;

    return Semantics(
      button: true,
      selected: selected,
      label:
          '$weekLabel${isCurrent ? ', this week' : ''}'
          '${rangeLabel.isEmpty ? '' : ', $rangeLabel'}'
          '${progress.total > 0 ? ', ${progress.done} of ${progress.total} done' : ''}',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minWidth: 132),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.18)
                  : context.palette.cardElevated,
              borderRadius: BorderRadius.circular(AppRadii.cardLarge),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : context.palette.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrent) ...[
                  Text(
                    'THIS WEEK',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  weekLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? accent : context.palette.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (rangeLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    rangeLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? accent.withValues(alpha: 0.9)
                          : context.palette.textMuted,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
                if (progress.total > 0) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 96,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: progress.done / progress.total,
                        minHeight: 4,
                        color: context.palette.statusGood,
                        backgroundColor: context.palette.border,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${progress.done}/${progress.total}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: context.palette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeekThemeChip extends StatelessWidget {
  const _WeekThemeChip({required this.theme});

  final String theme;

  @override
  Widget build(BuildContext context) {
    final accent = context.palette.accent;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: context.palette.border),
        ),
        child: Text(
          'Theme: $theme',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _WeekProgressBar extends StatelessWidget {
  const _WeekProgressBar({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final fraction = total == 0 ? 0.0 : done / total;

    return Semantics(
      label: '$done of $total done this week',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (total > 0 && done >= total) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: palette.statusGood,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                total > 0 && done >= total
                    ? 'Week complete'
                    : '$done of $total done',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(fraction * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: palette.statusGood,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: palette.statusGood,
                backgroundColor: palette.border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
