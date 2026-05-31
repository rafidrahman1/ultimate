import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../widgets/status_message.dart';
import 'insight_checklist_service.dart';
import 'insight_parser.dart';
import 'result_detail_screen.dart';
import 'results_service.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(analysisResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear all',
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: resultsAsync.when(
        data: (results) {
          if (results.isEmpty) {
            return const StatusMessage(
              icon: Icons.insights_outlined,
              title: 'No analysis results yet',
              subtitle:
                  'Run "Analyze data" from Home and your insight history will appear here.',
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: _ResultsSummaryBanner(count: results.length),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _ResultListCard(
                      result: item,
                      isLatest: index == 0,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not load results',
          subtitle: error.toString(),
        ),
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all results?'),
        content: const Text('This removes your saved insight history from this device.'),
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

  Future<void> _confirmDeleteResult(
    BuildContext context,
    WidgetRef ref,
    AnalysisResult result,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Text(
          'This removes "${result.title}" and its checklist progress from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref.read(analysisResultsProvider.notifier).deleteResult(result.id);
    await deleteChecklistDataForResult(result.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "${result.title}"')),
    );
  }
}

class _ResultsSummaryBanner extends StatelessWidget {
  const _ResultsSummaryBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.result.withValues(alpha: 0.14),
            theme.colorScheme.primary.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.result.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.result.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.insights, color: AppColors.result, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count saved ${count == 1 ? 'report' : 'reports'}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
    final dateFormat = DateFormat('d MMM yyyy · HH:mm');
    final preview = insightPreview(result.output);
    final sectionCount = parseInsightOutput(result.output).length;
    final sourceCount = _activeSourceCount(result.dataSnapshot);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onDelete,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isLatest)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.result.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Latest',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.result,
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
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
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
              Row(
                children: [
                  _MetaChip(
                    icon: Icons.view_agenda_outlined,
                    label: sectionCount > 0 ? '$sectionCount sections' : 'Full report',
                  ),
                  const SizedBox(width: 8),
                  _MetaChip(
                    icon: Icons.dataset_outlined,
                    label: '$sourceCount sources',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        borderRadius: BorderRadius.circular(20),
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
