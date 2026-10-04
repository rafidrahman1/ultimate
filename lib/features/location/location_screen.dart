import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/features/analysis/analysis_month_settings_service.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/location/location_insights_providers.dart';
import 'package:personal/features/location/location_panels.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/location/place_stats.dart';
import 'package:personal/features/location/mobility_prompt_builder.dart';
import 'package:personal/features/location/timeline_activity.dart';
import 'package:personal/features/location/timeline_profile.dart';
import 'package:personal/features/location/work_arrival_stats.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/status_message.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await ref.read(locationSummaryProvider.notifier).restoreFromCache();
    if (!mounted) return;
    await _loadAutoIfNeeded();
  }

  Future<void> _loadAutoIfNeeded() async {
    final current = ref.read(locationSummaryProvider);
    // Data cached by an older build lacks place detail; refresh it from the
    // folder when we can, and keep showing what we have if we can't.
    if (current.hasAnyData && !current.isLegacyCache) return;
    await _loadAuto();
  }

  Future<void> _loadAuto() async {
    final hasData = ref.read(locationSummaryProvider).hasAnyData;
    setState(() {
      if (!hasData) _loading = true;
      _loadError = null;
    });
    try {
      await ref.read(locationSummaryProvider.notifier).loadAuto();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _importJson(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(locationSummaryProvider.notifier).importFromPicker();
      if (!mounted) return;
      setState(() => _loadError = null);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _renamePlace(PlaceStat place) async {
    final names = ref.read(placeNamesProvider);
    final label = placeDisplayName(place, names);
    final custom = {
      for (final id in place.placeIds)
        if (names[id] != null) names[id]!,
    };
    final result = await showRenamePlaceDialog(
      context,
      current: custom.isEmpty ? '' : custom.first,
      fallback: label,
    );
    if (result == null) return;
    ref.read(placeNamesProvider.notifier).rename(place, result);
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(analysisPeriodProvider);
    final summary = ref.watch(locationForAnalysisProvider);
    final insights = ref.watch(locationInsightsProvider);
    final history = ref.watch(locationHistoryProvider);
    final placeNames = ref.watch(placeNamesProvider);
    final rawSummary = ref.watch(locationSummaryProvider);
    final settings = ref.watch(dataFolderSettingsProvider).valueOrNull;
    final hasFolder = settings?.hasFolder ?? false;
    final needsReselect = settings?.needsReselect ?? false;
    final motorcycleTrips = summary.sortedPeriodMotorcyclingActivities;
    final profile = ref.watch(promptConfigProvider).valueOrNull;
    final workAddress = profile?.workAddress ?? '';
    final workHours = profile?.workHours ?? '';
    final weekendDays = profile?.weekendDays ?? const [];
    final workArrivalStats = WorkArrivalStats.analyze(
      placeVisits: summary.placeVisits,
      workAddress: workAddress,
      workHours: workHours,
    );
    final fuel = mobilityFuelSummaryFromExpenses(
      ref.watch(expensesForAnalysisProvider),
    );

    ref.listen(dataFolderSettingsProvider, (previous, next) {
      final prevUri = previous?.valueOrNull?.folderUri;
      final nextUri = next.valueOrNull?.folderUri;
      if (prevUri != nextUri) _loadAuto();
    });

    return Scaffold(
      appBar: AppScreenAppBar.build(
        context,
        ref,
        title: 'Location',
        extraActions: [
          if (rawSummary.hasAnyData)
            AppBarCircularAction(
              icon: Icons.close,
              onPressed: () =>
                  ref.read(locationSummaryProvider.notifier).clear(),
            ),
          AppBarCircularAction(
            icon: Icons.refresh,
            onPressed: _loading ? null : _loadAuto,
          ),
        ],
      ),
      body: PullToRefresh(
        onRefresh: _loadAuto,
        child: _loading
            ? const CardListSkeleton(cardHeights: [210, 200, 72, 72, 72])
            : !summary.hasAnyData
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: StatusMessage(
                  icon: Icons.route_outlined,
                  title: rawSummary.hasAnyData
                      ? 'No location data in ${period.dataRangeLabel}'
                      : 'No location data loaded',
                  subtitle:
                      _loadError ??
                      (needsReselect
                          ? 'Open General settings and choose your data folder again '
                                'so Android can read files in that folder.'
                          : hasFolder
                          ? 'No Timeline export found in your selected folder. '
                                'Tap refresh after updating your export.'
                          : 'Choose your data folder in General settings, '
                                'or tap upload to import a Timeline JSON file manually.'),
                  action: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: hasFolder && !needsReselect
                            ? OutlinedButton(
                                onPressed: _loadAuto,
                                child: const Text('Reload'),
                              )
                            : FilledButton(
                                onPressed: () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.generalSettings,
                                ),
                                child: const Text('Open settings'),
                              ),
                      ),
                      if (!rawSummary.hasAnyData) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const TimelineExportHelp(),
                      ],
                    ],
                  ),
                ),
              )
            : _LocationBody(
                summary: summary,
                motorcycleTrips: motorcycleTrips,
                period: period,
                workArrivalStats: workArrivalStats,
                workAddress: workAddress,
                workHours: workHours,
                weekendDays: weekendDays,
                fuel: fuel,
                insights: insights,
                history: history,
                profile: rawSummary.profile,
                trips: rawSummary.trips,
                placeNames: placeNames,
                onRenamePlace: _renamePlace,
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _importJson(context),
        icon: const Icon(Icons.upload_file),
        label: const Text('Import JSON'),
      ),
    );
  }
}

class _LocationBody extends StatelessWidget {
  const _LocationBody({
    required this.summary,
    required this.motorcycleTrips,
    required this.period,
    required this.workArrivalStats,
    required this.workAddress,
    required this.workHours,
    required this.weekendDays,
    required this.insights,
    required this.history,
    required this.profile,
    required this.trips,
    required this.placeNames,
    required this.onRenamePlace,
    this.fuel,
  });

  final LocationSummary summary;
  final List<TimelineActivity> motorcycleTrips;
  final AnalysisPeriod period;
  final WorkArrivalStats workArrivalStats;
  final String workAddress;
  final String workHours;
  final List<int> weekendDays;
  final MobilityFuelSummary? fuel;
  final LocationInsights insights;
  final List<MonthlyLocationRow> history;
  final LocationProfile profile;
  final List<TimelineTrip> trips;
  final Map<String, String> placeNames;
  final Future<void> Function(PlaceStat place) onRenamePlace;

  @override
  Widget build(BuildContext context) {
    final decimal = NumberFormat.decimalPattern();
    final accent = AppSemanticColors.mobility(context);
    final other = AppSemanticColors.result(context);

    final motorcycleKm = summary.periodMotorcycleDistanceMeters / 1000;
    final totalKm = summary.periodTotalDistanceMeters / 1000;
    final otherKm = (totalKm - motorcycleKm).clamp(0.0, double.infinity);
    final leadsWithMotorcycle = motorcycleKm > 0;
    final headlineKm = leadsWithMotorcycle ? motorcycleKm : totalKm;

    final otherModes = summary.periodTransportationByType
        .where((mode) => mode.type != 'MOTORCYCLING')
        .toList();
    final weekendTrips = weekendDays.isEmpty
        ? const <TimelineActivity>[]
        : summary.periodMotorcycleActivitiesOnWeekendDays(weekendDays);
    final weekendKm =
        weekendTrips.fold(0.0, (sum, trip) => sum + trip.distanceMeters) / 1000;

    final days = buildDayBars([
      for (final a in summary.activities)
        if (leadsWithMotorcycle ? a.isMotorcycling : a.distanceMeters > 0)
          (date: a.startTime.toLocal(), value: a.distanceMeters / 1000),
    ], period.dataMonthStart);
    final groups = groupByDay(motorcycleTrips, (t) => t.startTime.toLocal());

    return CategoryScroll(
      slivers: [
        categoryBox(
          CategoryHero(
            accent: accent,
            icon: Icons.two_wheeler_rounded,
            label: leadsWithMotorcycle ? 'By motorcycle' : 'Distance travelled',
            value: headlineKm.toStringAsFixed(1),
            unit: 'km',
            caption: leadsWithMotorcycle
                ? '${decimal.format(motorcycleTrips.length)} trips'
                : '${decimal.format(summary.activities.length)} activities',
            footnote: period.dataRangeLabel,
            stats: [
              if (leadsWithMotorcycle)
                HeroStat(
                  'Travel time',
                  formatTravelDuration(summary.periodMotorcycleTravelTime),
                ),
              if (leadsWithMotorcycle && otherKm > 0)
                HeroStat('Other transport', '${otherKm.toStringAsFixed(1)} km'),
              if (weekendDays.isNotEmpty)
                HeroStat('Weekend rides', '${weekendKm.toStringAsFixed(1)} km'),
              if (fuel != null && fuel!.refuelCount > 0)
                HeroStat(
                  'Fuel spend',
                  '${currencyPrefix(fuel!.currency)}'
                      '${decimal.format(fuel!.totalSpend.round())}',
                ),
            ],
          ),
        ),
        categoryBox(
          CategoryPanel(
            title: leadsWithMotorcycle ? 'Rides by day' : 'Distance by day',
            child: DayBars(
              data: days,
              color: accent,
              format: (v) => '${v.toStringAsFixed(1)} km',
              emptyLabel: 'No trips recorded this month',
            ),
          ),
        ),
        if (insights.split.hasData)
          categoryBox(
            TimeSplitPanel(
              insights: insights,
              accent: accent,
              workColor: other,
            ),
          ),
        if (insights.commute.hasData)
          categoryBox(
            CommutePanel(
              commute: insights.commute,
              profile: profile,
              accent: accent,
            ),
          ),
        if (insights.places.isNotEmpty)
          categoryBox(
            PlacesPanel(
              insights: insights,
              names: placeNames,
              onRename: onRenamePlace,
              accent: accent,
            ),
          ),
        if (history.length >= 2)
          categoryBox(MonthlyTrendPanel(history: history, accent: accent)),
        if (trips.isNotEmpty)
          categoryBox(TripsAwayPanel(trips: trips, accent: accent)),
        if (workArrivalStats.hasWorkVisits && workArrivalStats.hasLateThreshold)
          categoryBox(
            _WorkArrivalsPanel(stats: workArrivalStats, accent: accent),
          ),
        if (otherModes.isNotEmpty)
          categoryBox(
            CategoryPanel(
              title: 'Other transport',
              child: BreakdownBars(
                color: other,
                items: [
                  for (final mode in otherModes)
                    (
                      label: _formatTransportType(mode.type),
                      value: mode.distanceMeters,
                      display:
                          '${(mode.distanceMeters / 1000).toStringAsFixed(1)} km · '
                          '${decimal.format(mode.tripCount)}',
                    ),
                ],
              ),
            ),
          ),
        categoryBox(const CategoryTitle('Trips'), bottom: AppSpacing.xs),
        if (groups.isEmpty)
          categoryBox(
            Text(
              'No motorcycle trips in this period.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
            ),
          )
        else
          categoryList(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final km =
                  group.value.fold(0.0, (sum, t) => sum + t.distanceMeters) /
                  1000;
              return DayGroup(
                date: group.key,
                accent: accent,
                total: '${km.toStringAsFixed(1)} km',
                children: [
                  for (final trip in group.value) _TripRow(trip: trip),
                ],
              );
            },
          ),
        categoryBox(
          AnalysisDataLink(
            promptText: summary.toAnalysisPromptText(
              dataMonthStart: period.dataMonthStart,
              dataMonthEnd: period.dataMonthEnd,
              workAddress: workAddress,
              workHours: workHours,
              weekendDays: weekendDays,
              fuel: fuel,
            ),
            title: 'Location data for analysis',
            accent: accent,
            icon: Icons.route_outlined,
          ),
        ),
      ],
    );
  }

  String _formatTransportType(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) return 'Unknown';
    return normalized
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

/// On-time vs late split for workdays, with the late days listed.
class _WorkArrivalsPanel extends StatelessWidget {
  const _WorkArrivalsPanel({required this.stats, required this.accent});

  final WorkArrivalStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final total = stats.totalWorkDays;
    final late = stats.lateArrivalCount;
    final onTime = (total - late).clamp(0, total);
    final dateFormat = DateFormat('EEE d MMM · h:mm a');
    final lateDays = stats.lateArrivals.take(5).toList();

    return CategoryPanel(
      title: 'Work arrivals',
      trailing: 'after ${stats.thresholdLabel}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$onTime',
                style: context.statDisplay.copyWith(color: accent),
              ),
              const SizedBox(width: 6),
              Text(
                'of $total workdays on time',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (onTime > 0)
                      Expanded(
                        flex: onTime,
                        child: ColoredBox(color: accent),
                      ),
                    if (late > 0)
                      Expanded(
                        flex: late,
                        child: ColoredBox(color: palette.warning),
                      ),
                  ],
                ),
              ),
            ),
          if (lateDays.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              '$late late ${late == 1 ? 'arrival' : 'arrivals'}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.warning,
              ),
            ),
            const SizedBox(height: 4),
            for (final day in lateDays)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  dateFormat.format(day.arrivalTime),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            if (stats.lateArrivals.length > lateDays.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${stats.lateArrivals.length - lateDays.length} more',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({required this.trip});

  final TimelineActivity trip;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a');
    final start = trip.startTime.toLocal();
    final end = trip.endTime.toLocal();
    return CategoryRow(
      icon: Icons.two_wheeler_outlined,
      accent: AppSemanticColors.mobility(context),
      title: '${(trip.distanceMeters / 1000).toStringAsFixed(2)} km',
      subtitle: '${time.format(start)} → ${time.format(end)}',
      trailing: formatTravelDuration(end.difference(start)),
    );
  }
}
