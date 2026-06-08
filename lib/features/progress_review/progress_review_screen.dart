import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/progress_review/progress_review_dashboard.dart';
import 'package:personal/features/progress_review/progress_review_view_data.dart';

class ProgressReviewScreen extends ConsumerWidget {
  const ProgressReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(progressReviewViewProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;

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
            child: ProgressReviewDashboard(data: data),
          ),
        ),
      ],
    );
  }
}
