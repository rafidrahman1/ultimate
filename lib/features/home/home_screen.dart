import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/app/router.dart';
import 'package:personal/features/home/widgets/feature_tile.dart';
import 'package:personal/features/health/health_service.dart';
import 'package:personal/features/home/home_features.dart';
import 'package:personal/shared/navigation/expand_page_route.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthlyHealth = ref.watch(monthlyHealthDataProvider);
    final expenses = ref.watch(expensesForAnalysisProvider);
    final location = ref.watch(locationForAnalysisProvider);
    final gameActivity = ref.watch(gameActivityForAnalysisProvider);
    final calendar = ref.watch(calendarSummaryProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    const extraBottomForNavPill = 90.0;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(28, 20, 28, bottomInset + extraBottomForNavPill),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 100,
      ),
      itemCount: homeFeatures.length,
      itemBuilder: (context, index) {
        final feature = homeFeatures[index];
        return Builder(
          builder: (tileContext) {
            return FeatureTile(
              label: feature.label,
              color: feature.colorFor(context),
              backgroundAsset: feature.backgroundAsset,
              dataLoaded: switch (feature.id) {
                HomeFeatureId.dashboard =>
                  monthlyHealth.maybeWhen(
                    data: (fetch) => fetch.hasData,
                    orElse: () => false,
                  ) ||
                  expenses.transactions.isNotEmpty ||
                  location.activities.isNotEmpty ||
                  gameActivity.sessions.isNotEmpty ||
                  calendar.events.isNotEmpty,
                HomeFeatureId.health => monthlyHealth.maybeWhen(
                  data: (fetch) => fetch.hasData,
                  orElse: () => false,
                ),
                HomeFeatureId.expenses => expenses.transactions.isNotEmpty,
                HomeFeatureId.location => location.activities.isNotEmpty,
                HomeFeatureId.gameActivity => gameActivity.sessions.isNotEmpty,
                HomeFeatureId.calendar => calendar.events.isNotEmpty,
                HomeFeatureId.prompt =>
                  monthlyHealth.maybeWhen(
                    data: (fetch) => fetch.hasData,
                    orElse: () => false,
                  ) ||
                  expenses.transactions.isNotEmpty ||
                  location.activities.isNotEmpty ||
                  gameActivity.sessions.isNotEmpty ||
                  calendar.events.isNotEmpty,
              },
              onPressed: () => pushExpandRoute(
                tileContext,
                page: AppRoutes.screenFor(feature.route),
                backdropColor: feature.colorFor(context),
                backgroundAsset: feature.backgroundAsset,
              ),
            );
          },
        );
      },
    );
  }
}
