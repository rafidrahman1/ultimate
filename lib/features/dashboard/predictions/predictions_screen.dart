import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/predictions_provider.dart';
import 'package:personal/features/dashboard/predictions/predictions_section.dart';
import 'package:personal/features/forecasts/prediction_selection_service.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/status_message.dart';

/// Every prediction the app makes, on its own tab.
class PredictionsScreen extends ConsumerWidget {
  const PredictionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predictions = ref.watch(predictionsProvider);
    final hasDisabled = ref.watch(predictionDisabledProvider).isNotEmpty;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (predictions.isEmpty && !hasDisabled) {
      return const StatusMessage(
        icon: Icons.auto_graph_outlined,
        title: 'No predictions yet',
        subtitle:
            'Predictions appear once there is enough expense, location or '
            'health history to estimate from.',
      );
    }

    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: () => refreshAllSources(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                bottomInset + AppLayout.navPillClearance,
              ),
              sliver: SliverToBoxAdapter(
                child: PredictionsSection(predictions: predictions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
