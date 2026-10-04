import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/error_display.dart';
import 'package:personal/features/analysis/analysis_kind.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/features/results/insights_models.dart';
import 'package:personal/features/results/insights_parser.dart';
import 'package:personal/features/results/result_detail_screen.dart';
import 'package:personal/features/results/results_service.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/features/home/analyze_options_dialog.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  String _query = '';
  AnalysisKind? _kind;

  bool _matches(AnalysisResult result) {
    if (_kind != null && result.analysisKind != _kind) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return result.title.toLowerCase().contains(query) ||
        result.output.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(analysisResultsProvider);
    const bottomScrollPadding = 24.0;

    final body = resultsAsync.when(
      data: (results) {
        if (results.isEmpty) {
          return SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomScrollPadding),
            child: StatusMessage(
              icon: Icons.insights_outlined,
              title: 'No analysis results yet',
              subtitle: 'Run monthly insights to generate your first report.',
              action: Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: () => showAnalyzeOptionsDialog(
                    context: context,
                    ref: ref,
                    buttonContext: buttonContext,
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Analyze'),
                ),
              ),
            ),
          );
        }

        final visible = results.where(_matches).toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _ResultsSummaryBanner(count: results.length),
              ),
            ),
            SliverToBoxAdapter(
              child: _ResultsFilterBar(
                kind: _kind,
                onQueryChanged: (value) => setState(() => _query = value),
                onKindChanged: (value) => setState(() => _kind = value),
              ),
            ),
            if (visible.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: Text('No reports match.')),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                8,
                AppSpacing.screen,
                bottomScrollPadding,
              ),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = visible[index];
                  return _ResultListCard(
                    result: item,
                    isLatest: item.id == results.first.id,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ResultDetailScreen(result: item),
                        ),
                      );
                    },
                    onDelete: () => _confirmDeleteResult(context, ref, item),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const CardListSkeleton(cardHeights: [96, 96, 96, 96]),
      error: (error, _) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomScrollPadding),
        child: StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load results',
          subtitle: humanizeError(error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(analysisResultsProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Results',
        showBack: true,
        extraActions: [
          AppBarCircularAction(
            icon: Icons.delete_sweep_outlined,
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all results?'),
        content: const Text(
          'This removes your saved insight history from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(analysisResultsProvider.notifier).clearAll();
  }

  /// Deletes immediately; the snackbar offers undo instead of a confirm step.
  Future<void> _confirmDeleteResult(
    BuildContext context,
    WidgetRef ref,
    AnalysisResult result,
  ) async {
    final notifier = ref.read(analysisResultsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    await notifier.deleteResult(result.id);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${result.title}"'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => notifier.addResult(result),
          ),
        ),
      );
  }
}

class _ResultsFilterBar extends StatelessWidget {
  const _ResultsFilterBar({
    required this.kind,
    required this.onQueryChanged,
    required this.onKindChanged,
  });

  final AnalysisKind? kind;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AnalysisKind?> onKindChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        4,
        AppSpacing.screen,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search reports',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: kind == null,
                onSelected: (_) => onKindChanged(null),
              ),
              for (final value in AnalysisKind.values)
                ChoiceChip(
                  label: Text(value.displayName),
                  selected: kind == value,
                  onSelected: (_) => onKindChanged(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultsSummaryBanner extends StatelessWidget {
  const _ResultsSummaryBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.palette.accent;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.cardLarge),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            theme.colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.cardLarge),
            ),
            child: Icon(Icons.insights, color: accent, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count saved ${count == 1 ? 'report' : 'reports'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a card to read the full insight breakdown. Long press to delete.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultListCard extends StatelessWidget {
  const _ResultListCard({
    required this.result,
    required this.isLatest,
    required this.onTap,
    required this.onDelete,
  });

  final AnalysisResult result;
  final bool isLatest;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.palette.accent;
    final dateFormat = DateFormat('d MMM yyyy · HH:mm');
    final report = InsightsReportParser.parse(result.output);
    final preview = _previewFor(report, result.output);
    final actionCount = report.actions.length;
    final sourceCount = _activeSourceCount(result.dataSnapshot);

    return Semantics(
      button: true,
      label:
          '${result.title}, ${dateFormat.format(result.createdAt.toLocal())}',
      onLongPressHint: 'Delete report',
      child: AppCard(
        onTap: onTap,
        onLongPress: onDelete,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isLatest)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadii.cardLarge),
                    ),
                    child: Text(
                      'Latest',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  result.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(result.createdAt.toLocal()),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              preview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.view_agenda_outlined,
                  label: actionCount > 0
                      ? '$actionCount actions'
                      : 'Full report',
                ),
                _MetaChip(
                  icon: Icons.dataset_outlined,
                  label: '$sourceCount sources',
                ),
                if (result.aiProviderLabel != null)
                  _MetaChip(
                    icon: _aiProviderIcon(result.aiProvider),
                    label: result.aiProviderLabel!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _aiProviderIcon(String? provider) {
    return switch (provider) {
      'openai' => Icons.auto_awesome,
      'gemini' => Icons.bolt,
      _ => Icons.smart_toy_outlined,
    };
  }

  static String _previewFor(InsightsParsedReport report, String output) {
    const maxLength = 140;
    final lead = report.anomalies.isNotEmpty ? report.anomalies.first : null;
    var text = lead == null
        ? output
        : (lead.description.isNotEmpty ? lead.description : lead.title);
    text = text
        .replaceAll(RegExp(r'[#*_`>]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';
  }

  int _activeSourceCount(Map<String, String> snapshot) {
    var count = 0;
    for (final value in snapshot.values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && !trimmed.toLowerCase().startsWith('no ')) {
        count++;
      }
    }
    return count;
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
