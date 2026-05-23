import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../results/analysis_service.dart';
import '../../shell/app_drawer.dart';
import '../../widgets/feature_tile.dart';
import 'home_features.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runState = ref.watch(analysisRunProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Personal')),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Your data hub',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'Connect sources and analyze insights in one place.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                    icon: feature.icon,
                    color: feature.color,
                    enabled: feature.route != null,
                    onPressed: feature.route == null
                        ? null
                        : () => Navigator.pushNamed(context, feature.route!),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: FilledButton.icon(
                onPressed: runState.isRunning
                    ? null
                    : () async {
                        await ref.read(analysisRunProvider.notifier).runAnalysis();
                        if (!context.mounted) return;
                        final latest = ref.read(analysisRunProvider);
                        if (latest.lastError != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(latest.lastError!)),
                          );
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Analysis completed and saved')),
                        );
                        Navigator.pushNamed(context, AppRoutes.results);
                      },
                icon: runState.isRunning
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.analytics_outlined),
                label: Text(runState.isRunning ? 'Analyzing...' : 'Analyze data'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
