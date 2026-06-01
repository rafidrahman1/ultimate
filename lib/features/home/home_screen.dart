import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/analysis_view_providers.dart';
import '../../shell/app_drawer.dart';
import '../../widgets/feature_tile.dart';
import '../../widgets/home_checklist_icon.dart';
import '../health/health_service.dart';
import '../results/analysis_service.dart';
import '../results/results_service.dart';
import '../results/selected_checklist_result_service.dart';
import 'home_features.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runState = ref.watch(analysisRunProvider);
    final monthlyHealth = ref.watch(monthlyHealthDataProvider);
    final expenses = ref.watch(expensesForAnalysisProvider);
    final location = ref.watch(locationForAnalysisProvider);
    final gameActivity = ref.watch(gameActivityForAnalysisProvider);
    final calendar = ref.watch(calendarForAnalysisProvider);
    final results = ref.watch(analysisResultsProvider).valueOrNull ?? const [];
    final withChecklist = analysisResultsWithChecklist(results);
    final effectiveChecklistId = resolveSelectedChecklistResultId(withChecklist: withChecklist, storedId: ref.watch(selectedChecklistResultIdProvider));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [_HomeChecklistAppBarButton(results: withChecklist, selectedId: effectiveChecklistId)],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text('Data hub', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.05),
                itemCount: homeFeatures.length,
                itemBuilder: (context, index) {
                  final feature = homeFeatures[index];
                  return FeatureTile(
                    label: feature.label,
                    icon: feature.icon,
                    color: feature.color,
                    dataLoaded: switch (feature.id) {
                      HomeFeatureId.health => monthlyHealth.maybeWhen(data: (fetch) => fetch.hasData, orElse: () => false),
                      HomeFeatureId.expenses => expenses.transactions.isNotEmpty,
                      HomeFeatureId.location => location.activities.isNotEmpty,
                      HomeFeatureId.gameActivity => gameActivity.sessions.isNotEmpty,
                      HomeFeatureId.calendar => calendar.events.isNotEmpty,
                      _ => false,
                    },
                    onPressed: () => Navigator.pushNamed(context, feature.route),
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
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(latest.lastError!)));
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analysis completed and saved')));
                        Navigator.pushNamed(context, AppRoutes.results);
                      },
                icon: runState.isRunning ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.analytics_outlined),
                label: Text(runState.isRunning ? 'Analyzing...' : 'Analyze data'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeChecklistAppBarButton extends ConsumerStatefulWidget {
  const _HomeChecklistAppBarButton({required this.results, required this.selectedId});

  final List<AnalysisResult> results;
  final String? selectedId;

  @override
  ConsumerState<_HomeChecklistAppBarButton> createState() => _HomeChecklistAppBarButtonState();
}

class _HomeChecklistAppBarButtonState extends ConsumerState<_HomeChecklistAppBarButton> {
  final _anchorKey = GlobalKey();

  Future<void> _showResultPicker() async {
    final anchorContext = _anchorKey.currentContext;
    if (anchorContext == null || widget.results.isEmpty) return;

    final box = anchorContext.findRenderObject()! as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final dateFormat = DateFormat('d MMM yyyy');

    final picked = await showMenu<String>(
      context: anchorContext,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy + size.height, offset.dx + size.width, offset.dy),
      items: [
        for (final result in widget.results)
          PopupMenuItem<String>(
            value: result.id,
            child: Row(
              children: [
                SizedBox(width: 24, child: result.id == widget.selectedId ? HomeChecklistIcon(selected: true, size: 20) : null),
                const SizedBox(width: 8),
                Expanded(child: Text('${result.title} · ${dateFormat.format(result.createdAt.toLocal())}', overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
    );

    if (picked == null || !mounted) return;
    await ref.read(selectedChecklistResultIdProvider.notifier).select(picked);
    if (!mounted) return;
    final title = widget.results.firstWhere((r) => r.id == picked).title;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Home checklist: $title')));
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = widget.results.isNotEmpty;

    final isPinned = widget.selectedId != null;

    return IconButton(
      key: _anchorKey,
      icon: HomeChecklistIcon(selected: isPinned && hasResults),
      tooltip: hasResults ? 'Open checklist · long press to choose report' : 'Weekly checklists',
      onPressed: () => Navigator.pushNamed(context, AppRoutes.weeklyChecklists),
      onLongPress: hasResults ? _showResultPicker : null,
    );
  }
}
