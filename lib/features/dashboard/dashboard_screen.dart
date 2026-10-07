import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/error_display.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/features/dashboard/dashboard_charts.dart';
import 'package:personal/features/dashboard/dashboard_layout_service.dart';
import 'package:personal/features/dashboard/dashboard_provider.dart';
import 'package:personal/features/dashboard/dashboard_view_data.dart';
import 'package:personal/features/dashboard/predictions_provider.dart';
import 'package:personal/features/dashboard/predictions_section.dart';
import 'package:personal/features/home/home_refresh.dart';
import 'package:personal/shared/navigation/fade_scale_page_route.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';

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

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data, required this.bottomInset});

  final DashboardViewData data;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(dashboardCardOrderProvider);
    final visible = order.where((id) => _cardFor(id) != null).toList();
    final predictions = ref.watch(predictionsProvider);

    return ContentWidth(
      child: RefreshIndicator(
        onRefresh: () => refreshAllSources(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    DashboardCoverageHeader(data: data),
                    const SizedBox(height: 20),
                    Text('SOURCES', style: context.sectionLabel),
                    const SizedBox(height: AppSpacing.sm),
                    DashboardDomainGrid(
                      domains: data.domains,
                      colorFor: (id) => _colorForDomain(context, id),
                      onOpen: (id) {
                        final route = _routeForDomain(id);
                        if (route == null) return;
                        pushFadeScaleRoute(
                          context,
                          page: AppRoutes.screenFor(route),
                        );
                      },
                    ),
                    if (!predictions.isEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      PredictionsSection(predictions: predictions),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    Row(
                      children: [
                        Expanded(
                          child: Text('ANALYSIS', style: context.sectionLabel),
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

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.section});

  final DashboardHealthAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.health(context);

    return DashboardSectionCard(
      title: 'Sleep analysis',
      subtitle:
          '${section.nightsTracked} nights · ${section.nightsBelowTarget} below 7h target',
      icon: Icons.bedtime_rounded,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardLeadRow(
            percent: section.recoveryRatePercent,
            ringLabel: 'recovery',
            ringColor: AppSemanticColors.accent(context),
            metrics: [
              (
                label: 'Sleep debt',
                value: '${section.sleepDebtHours.toStringAsFixed(1)} h',
                color: color,
              ),
              (
                label: 'Bedtime σ',
                value: section.bedtimeStdDevMinutes != null
                    ? '${section.bedtimeStdDevMinutes!.round()} m'
                    : '—',
                color: color,
              ),
              if (section.recoveryRatePercent == null)
                (label: 'Recovery', value: '—', color: color),
            ],
          ),
          if (section.clusters.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Short-sleep clusters',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DashboardHorizontalBars(items: section.clusters, color: color),
          ],
          const SizedBox(height: 18),
          Text(
            'Daily sleep vs 7h target',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DashboardColumnChart(
            items: section.dailySleep,
            color: color,
            targetLine: 7,
          ),
        ],
      ),
    );
  }
}

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({required this.section});

  final DashboardFinancialAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.expenses(context);
    final amountFormat = NumberFormat.currency(
      symbol: currencyPrefix(section.currency),
      decimalDigits: 0,
    );

    return DashboardSectionCard(
      title: 'Financial analysis',
      subtitle: section.topCategoryName != null
          ? 'Top category: ${section.topCategoryName}'
          : 'Budget and concentration metrics',
      icon: Icons.account_balance_wallet_rounded,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardLeadRow(
            percent: section.budgetConsumedPercent,
            ringLabel: 'of budget',
            ringColor: color,
            metrics: [
              (
                label: 'Income used',
                value: section.incomeUtilizationPercent != null
                    ? '${section.incomeUtilizationPercent!.toStringAsFixed(0)}%'
                    : '—',
                color: AppSemanticColors.accent(context),
              ),
              (
                label: 'Net',
                value: amountFormat.format(section.netSurplus),
                color: AppSemanticColors.result(context),
              ),
              if (section.budgetConsumedPercent == null)
                (label: 'Budget used', value: '—', color: color),
            ],
          ),
          if (section.topCategorySharePercent != null ||
              section.top3CategorySharePercent != null) ...[
            const SizedBox(height: 18),
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Top category',
                  value: section.topCategorySharePercent != null
                      ? '${section.topCategorySharePercent!.toStringAsFixed(0)}%'
                      : '—',
                  color: color,
                ),
                (
                  label: 'Top 3 share',
                  value: section.top3CategorySharePercent != null
                      ? '${section.top3CategorySharePercent!.toStringAsFixed(0)}%'
                      : '—',
                  color: color,
                ),
                (
                  label: 'Burn rate',
                  value: section.burnRatePercent != null
                      ? '${section.burnRatePercent!.toStringAsFixed(0)}%'
                      : '—',
                  color: AppSemanticColors.mobility(context),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Category concentration',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DashboardHorizontalBars(
            items: section.categoryConcentration,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _MobilitySection extends StatelessWidget {
  const _MobilitySection({required this.section});

  final DashboardMobilityAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.location(context);
    final rideChange = section.rideDistanceChangeKm;

    return DashboardSectionCard(
      title: 'Mobility analysis',
      subtitle:
          '${section.motorcycleKm.toStringAsFixed(1)} km by motorcycle · '
          '${section.workDays} work days',
      icon: Icons.route_rounded,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardLeadRow(
            percent: section.lateArrivalRatePercent,
            ringLabel: 'late rate',
            ringColor: context.palette.warning,
            metrics: [
              (
                label: 'Late days',
                value: '${section.lateArrivals}',
                color: color,
              ),
              (
                label: 'Avg delay',
                value: section.averageDelayMinutes != null
                    ? '${section.averageDelayMinutes!.round()} m'
                    : '—',
                color: AppSemanticColors.accent(context),
              ),
              if (section.lateArrivalRatePercent == null)
                (label: 'Late rate', value: '—', color: color),
            ],
          ),
          if (section.fuelSpend != null) ...[
            const SizedBox(height: 16),
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Fuel spend',
                  value: section.fuelSpend!.toStringAsFixed(0),
                  color: AppSemanticColors.expenses(context),
                ),
                (
                  label: 'Refuels',
                  value: '${section.fuelRefuelCount ?? 0}',
                  color: color,
                ),
                (
                  label: 'Travel time',
                  value: '${section.travelTimeHours.toStringAsFixed(1)} h',
                  color: color,
                ),
              ],
            ),
          ],
          if (section.fuelLitres != null) ...[
            const SizedBox(height: 16),
            DashboardMetricRow(
              metrics: [
                (
                  label: 'Fuel bought',
                  value: '${section.fuelLitres!.toStringAsFixed(1)} L',
                  color: color,
                ),
                (
                  label: 'Avg price',
                  value: section.fuelRatePerLitre != null
                      ? '${currencyPrefix(section.fuelCurrency)}'
                            '${section.fuelRatePerLitre!.toStringAsFixed(1)}/L'
                      : '—',
                  color: AppSemanticColors.expenses(context),
                ),
              ],
            ),
            if ((section.fuelPricedRefuelCount ?? 0) <
                (section.fuelRefuelCount ?? 0)) ...[
              const SizedBox(height: 8),
              Text(
                'Litres from ${section.fuelPricedRefuelCount} of '
                '${section.fuelRefuelCount} refuels — add a rate like '
                '"125/L" to the other descriptions.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          if (section.rideDistanceKm != null) ...[
            const SizedBox(height: 16),
            Text(
              rideChange != null
                  ? 'Motorcycle distance: ${section.rideDistanceKm!.toStringAsFixed(1)} km '
                        '(${rideChange >= 0 ? '+' : ''}${rideChange.toStringAsFixed(1)} km vs prior month)'
                  : 'Motorcycle distance: ${section.rideDistanceKm!.toStringAsFixed(1)} km',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (section.byTransport.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Distance by mode',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DashboardHorizontalBars(items: section.byTransport, color: color),
          ],
        ],
      ),
    );
  }
}

class _GamingSection extends StatelessWidget {
  const _GamingSection({required this.section});

  final DashboardGamingAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.gameActivity(context);
    final hoursLabel = section.totalPlayHours >= 1
        ? '${section.totalPlayHours.toStringAsFixed(1)} h'
        : '${(section.totalPlayHours * 60).round()} m';

    return DashboardSectionCard(
      title: 'Gaming trend',
      subtitle: section.sessionChange != null
          ? '$hoursLabel · ${section.sessionChange! >= 0 ? '+' : ''}${section.sessionChange} sessions vs prior month'
          : '$hoursLabel · ${section.sessionCount} sessions',
      icon: Icons.sports_esports_rounded,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardMetricRow(
            metrics: [
              (label: 'Play time', value: hoursLabel, color: color),
              (
                label: 'Sessions',
                value: '${section.sessionCount}',
                color: color,
              ),
              (
                label: 'Δ play time',
                value: section.playTimeChangeHours != null
                    ? '${section.playTimeChangeHours! >= 0 ? '+' : ''}${section.playTimeChangeHours!.toStringAsFixed(1)} h'
                    : '—',
                color: AppSemanticColors.accent(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Time by game',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DashboardHorizontalBars(items: section.byGame, color: color),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({required this.section});

  final DashboardCalendarAnalysis section;

  @override
  Widget build(BuildContext context) {
    final color = AppSemanticColors.calendar(context);

    return DashboardSectionCard(
      title: 'Calendar load',
      subtitle:
          '${section.majorEventCount} major events · '
          '${section.expenseLinkedEventCount} expense-linked',
      icon: Icons.calendar_month_rounded,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardMetricRow(
            metrics: [
              (
                label: 'Major',
                value: '${section.majorEventCount}',
                color: color,
              ),
              (
                label: 'Holidays',
                value: '${section.holidayCount}',
                color: color,
              ),
              (
                label: 'Expense-linked',
                value: '${section.expenseLinkedEventCount}',
                color: AppSemanticColors.expenses(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Events by weekday',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          DashboardColumnChart(
            items: section.byWeekday,
            color: color,
            height: 140,
          ),
        ],
      ),
    );
  }
}

String? _routeForDomain(String id) => switch (id) {
  'health' => AppRoutes.healthData,
  'expenses' => AppRoutes.expenses,
  'location' => AppRoutes.location,
  'gaming' => AppRoutes.gameActivity,
  'calendar' => AppRoutes.calendar,
  _ => null,
};

Color _colorForDomain(BuildContext context, String id) {
  return switch (id) {
    'health' => AppSemanticColors.health(context),
    'expenses' => AppSemanticColors.expenses(context),
    'location' => AppSemanticColors.location(context),
    'gaming' => AppSemanticColors.gameActivity(context),
    'calendar' => AppSemanticColors.calendar(context),
    _ => AppSemanticColors.accent(context),
  };
}
