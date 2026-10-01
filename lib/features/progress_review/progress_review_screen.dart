import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/progress_review/progress_review_dashboard.dart';
import 'package:personal/features/progress_review/progress_review_view_data.dart';
import 'package:personal/core/theme/app_theme.dart';

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
            AppSpacing.screen,
            12,
            AppSpacing.screen,
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
