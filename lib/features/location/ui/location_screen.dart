import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/app/router.dart';
import 'package:personal/core/formatting.dart';
import 'package:personal/core/period/analysis_month_settings_service.dart';
import 'package:personal/core/period/analysis_period.dart';
import 'package:personal/core/storage/data_folder_settings_service.dart';
import 'package:personal/core/theme/app_semantic_colors.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/location/analysis/mobility_prompt_builder.dart';
import 'package:personal/features/location/analysis/place_identify_ai.dart';
import 'package:personal/features/location/analysis/place_stats.dart';
import 'package:personal/features/location/analysis/work_arrival_stats.dart';
import 'package:personal/features/location/data/location_insights_providers.dart';
import 'package:personal/features/location/data/location_service.dart';
import 'package:personal/features/location/data/timeline_activity.dart';
import 'package:personal/features/location/data/timeline_profile.dart';
import 'package:personal/features/location/ui/location_panels.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/category/category_bits.dart';
import 'package:personal/shared/widgets/category/category_hero.dart';
import 'package:personal/shared/widgets/category/category_scroll.dart';
import 'package:personal/shared/widgets/category/day_bars.dart';
import 'package:personal/shared/widgets/pinned_summary_skeleton.dart';
import 'package:personal/shared/widgets/pull_to_refresh.dart';
import 'package:personal/shared/widgets/status_message.dart';

part 'location_arrival_panels.dart';
part 'location_body.dart';

class LocationScreen extends ConsumerStatefulWidget {
  const LocationScreen({super.key});

  @override
  ConsumerState<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends ConsumerState<LocationScreen> {
  bool _loading = false;
  String? _loadError;
  bool _identifying = false;

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

  Future<void> _identifyPlaces() async {
    final settings = ref.read(aiSettingsProvider).valueOrNull;
    final messenger = ScaffoldMessenger.of(context);
    if (settings == null || !canIdentifyPlaces(settings)) return;
    final targets = placesToIdentify(
      ref.read(locationInsightsProvider).places,
      ref.read(placeNamesProvider),
    );
    if (targets.isEmpty) return;
    setState(() => _identifying = true);
    try {
      final summary = ref.read(locationSummaryProvider);
      final found = await identifyPlacesWithAi(
        settings: settings,
        places: targets,
        visits: summary.placeVisits,
        workAddress:
            ref.read(promptConfigProvider).valueOrNull?.workAddress ?? '',
      );
      ref.read(placeNamesProvider.notifier).suggest(found);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Named ${found.length} ${found.length == 1 ? 'place' : 'places'}. '
            'Tap one to correct it.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not identify places: $e')),
      );
    } finally {
      if (mounted) setState(() => _identifying = false);
    }
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

    final ai = ref.watch(aiSettingsProvider).valueOrNull;
    final canIdentify =
        ai != null &&
        canIdentifyPlaces(ai) &&
        placesToIdentify(insights.places, placeNames).isNotEmpty;

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
                                  arguments: SettingsSection.storage,
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
                onIdentify: canIdentify ? _identifyPlaces : null,
                identifying: _identifying,
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
