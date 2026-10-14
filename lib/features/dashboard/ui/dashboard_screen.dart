import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/core/error_display.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/dashboard/predictions/predictions_provider.dart';
import 'package:personal/features/dashboard/predictions/predictions_section.dart';
import 'package:personal/features/dashboard/ui/dashboard_charts.dart';
import 'package:personal/features/dashboard/view/dashboard_layout_service.dart';
import 'package:personal/features/dashboard/view/dashboard_provider.dart';
import 'package:personal/features/dashboard/view/dashboard_view_data.dart';
import 'package:personal/features/forecasts/prediction_selection_service.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';

part 'dashboard_health_finance_sections.dart';
part 'dashboard_activity_sections.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dashboardViewProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Dashboard'),
      body: dataAsync.when(
        loading: () => CardListSkeleton(bottomPadding: bottomInset + 24),
        error: (error, _) => StatusMessage(
          icon: Icons.error_outline,
          title: 'Could not build dashboard',
          subtitle: humanizeError(error),
          action: OutlinedButton(
            onPressed: () => ref.invalidate(dashboardViewProvider),
            child: const Text('Try again'),
          ),
        ),
        data: (data) => data.hasAnyData
            ? _DashboardBody(data: data, bottomInset: bottomInset)
            : StatusMessage(
                icon: Icons.dashboard_outlined,
                title: 'No analysis data yet',
                subtitle:
                    'Import health, expenses, location, gaming, or calendar '
                    'data from Home for ${data.periodLabel}.',
                action: FilledButton(
                  onPressed: () => Navigator.maybePop(context),
                  child: const Text('Back to Home'),
                ),
              ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({required this.data, required this.bottomInset});

  final DashboardViewData data;
  final double bottomInset;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  final _cardKeys = {for (final id in DashboardCardId.values) id: GlobalKey()};

  DashboardViewData get data => widget.data;

  /// Expands [id] and scrolls it into view once the expansion has laid out.
  void _openCard(DashboardCardId id) {
    ref.read(dashboardExpandedCardsProvider.notifier).expand(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardContext = _cardKeys[id]?.currentContext;
      if (cardContext == null || !cardContext.mounted) return;
      Scrollable.ensureVisible(
        cardContext,
        duration: MediaQuery.disableAnimationsOf(cardContext)
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = widget.bottomInset;
    final order = ref.watch(dashboardCardOrderProvider);
    final visible = order.where((id) => _cardFor(id) != null).toList();
    final predictions = ref.watch(predictionsProvider);

    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: () => refreshAllSources(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Keep every card built so a headline tap can scroll to any of them.
          scrollCacheExtent: const ScrollCacheExtent.pixels(4000),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                12,
                AppSpacing.screen,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardCoverageHeader(data: data, onOpenCard: _openCard),
                    const SizedBox(height: 20),
                    if (!predictions.isEmpty ||
                        ref.watch(predictionDisabledProvider).isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      PredictionsSection(predictions: predictions),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'ANALYSIS · HOLD A CARD TO REORDER',
                              style: context.sectionLabel,
                            ),
                          ),
                        ),
                        if (!ref
                            .read(dashboardCardOrderProvider.notifier)
                            .isDefaultOrder)
                          TextButton(
                            onPressed: () => ref
                                .read(dashboardCardOrderProvider.notifier)
                                .reset(),
                            child: const Text('Reset order'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                0,
                AppSpacing.screen,
                bottomInset + 24,
              ),
              sliver: SliverReorderableList(
                itemCount: visible.length,
                onReorderStart: (_) => HapticFeedback.mediumImpact(),
                onReorderItem: (oldIndex, newIndex) => ref
                    .read(dashboardCardOrderProvider.notifier)
                    .reorderVisible(
                      visible: visible,
                      oldIndex: oldIndex,
                      newIndex: newIndex,
                    ),
                proxyDecorator: (child, _, animation) => AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Transform.scale(
                    scale: 1 + 0.02 * Curves.easeOut.transform(animation.value),
                    child: Material(
                      type: MaterialType.transparency,
                      child: child,
                    ),
                  ),
                  child: child,
                ),
                itemBuilder: (context, index) {
                  final id = visible[index];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(id),
                    index: index,
                    child: Padding(
                      key: _cardKeys[id],
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _cardFor(id),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _cardFor(DashboardCardId id) {
    return switch (id) {
      DashboardCardId.stableMonth =>
        data.stableMonth == null
            ? null
            : DashboardStableMonthCard(section: data.stableMonth!),
      DashboardCardId.health =>
        data.health == null ? null : _HealthSection(section: data.health!),
      DashboardCardId.financial =>
        data.financial == null
            ? null
            : _FinancialSection(section: data.financial!),
      DashboardCardId.mobility =>
        data.mobility == null
            ? null
            : _MobilitySection(section: data.mobility!),
      DashboardCardId.gaming =>
        data.gaming == null ? null : _GamingSection(section: data.gaming!),
      DashboardCardId.calendar =>
        data.calendar == null
            ? null
            : _CalendarSection(section: data.calendar!),
    };
  }
}
