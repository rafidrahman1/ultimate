import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_kind.dart';
import '../../widgets/status_message.dart';
import '../results/results_service.dart';
import 'progress_review_dashboard.dart';

List<AnalysisResult> progressReviewResults(List<AnalysisResult> results) {
  return results
      .where((result) => result.analysisKind == AnalysisKind.progressReview)
      .toList();
}

class ProgressReviewScreen extends ConsumerWidget {
  const ProgressReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(analysisResultsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => StatusMessage(
        icon: Icons.error_outline,
        title: 'Could not load progress reviews',
        subtitle: error.toString(),
      ),
      data: (results) {
        final reviews = progressReviewResults(results);
        if (reviews.isEmpty) {
          return StatusMessage(
            icon: Icons.trending_up_outlined,
            title: 'No progress review yet',
            subtitle:
                'Run monthly insights from Home, then start a progress review '
                'from the analyze button in the top-right corner.',
          );
        }

        final latest = reviews.first;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                bottomInset + extraBottomForNavPill,
              ),
              sliver: SliverToBoxAdapter(
                child: ProgressReviewDashboard(
                  rawMarkdown: latest.output,
                  title: latest.title,
                  generatedAt: latest.createdAt,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
