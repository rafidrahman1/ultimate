import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_view_providers.dart';
import '../../widgets/feature_tile.dart';
import '../health/health_service.dart';
import 'home_features.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyHealth = ref.watch(monthlyHealthDataProvider);
    final expenses = ref.watch(expensesForAnalysisProvider);
    final location = ref.watch(locationForAnalysisProvider);
    final gameActivity = ref.watch(gameActivityForAnalysisProvider);
    final calendar = ref.watch(calendarForAnalysisProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + extraBottomForNavPill),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: homeFeatures.length,
      itemBuilder: (context, index) {
        final feature = homeFeatures[index];
        return FeatureTile(
          label: feature.label,
          color: feature.color,
          backgroundAsset: feature.backgroundAsset,
          dataLoaded: switch (feature.id) {
            HomeFeatureId.health => monthlyHealth.maybeWhen(
              data: (fetch) => fetch.hasData,
              orElse: () => false,
            ),
            HomeFeatureId.expenses => expenses.transactions.isNotEmpty,
            HomeFeatureId.location => location.activities.isNotEmpty,
            HomeFeatureId.gameActivity => gameActivity.sessions.isNotEmpty,
            HomeFeatureId.calendar => calendar.events.isNotEmpty,
          },
          onPressed: () => Navigator.pushNamed(context, feature.route),
        );
      },
    );
  }
}
