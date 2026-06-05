import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analysis_view_providers.dart';
import '../../widgets/feature_tile.dart';
import '../health/health_service.dart';
import 'home_features.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onOpenDrawer});

  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthlyHealth = ref.watch(monthlyHealthDataProvider);
    final expenses = ref.watch(expensesForAnalysisProvider);
    final location = ref.watch(locationForAnalysisProvider);
    final gameActivity = ref.watch(gameActivityForAnalysisProvider);
    final calendar = ref.watch(calendarForAnalysisProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onOpenDrawer,
        ),
        title: const Text('Home'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Data hub',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                      HomeFeatureId.expenses =>
                        expenses.transactions.isNotEmpty,
                      HomeFeatureId.location =>
                        location.activities.isNotEmpty,
                      HomeFeatureId.gameActivity =>
                        gameActivity.sessions.isNotEmpty,
                      HomeFeatureId.calendar => calendar.events.isNotEmpty,
                    },
                    onPressed: () =>
                        Navigator.pushNamed(context, feature.route),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
