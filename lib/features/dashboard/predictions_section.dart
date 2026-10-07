import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/dashboard/prediction_cards.dart';
import 'package:personal/features/dashboard/prediction_chooser.dart';
import 'package:personal/features/dashboard/prediction_list.dart';
import 'package:personal/features/dashboard/predictions_provider.dart';
import 'package:personal/features/expenses/expense_panels.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/expenses/fuel_forecast.dart';
import 'package:personal/features/expenses/fuel_forecast_ai.dart';
import 'package:personal/features/expenses/fuel_forecast_ai_service.dart';
import 'package:personal/features/expenses/outlook_ai.dart';
import 'package:personal/features/expenses/outlook_ai_service.dart';
import 'package:personal/features/forecasts/life_forecast.dart';
import 'package:personal/features/forecasts/life_forecast_ai.dart';
import 'package:personal/features/forecasts/life_forecast_ai_service.dart';
import 'package:personal/features/dashboard/life_forecast_panel.dart';
import 'package:personal/features/location/location_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Next fuel purchase, upcoming bills and where the month is heading.
class PredictionsSection extends ConsumerStatefulWidget {
  const PredictionsSection({super.key, required this.predictions});

  final Predictions predictions;

  @override
  ConsumerState<PredictionsSection> createState() => _PredictionsSectionState();
}

class _PredictionsSectionState extends ConsumerState<PredictionsSection> {
  final _busy = <String>{};
  final _errors = <String, String>{};

  /// Bumped on every busy/error change so an open detail sheet rebuilds.
  final _tick = ValueNotifier<int>(0);

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  /// Runs one prediction's refinement, with its own busy flag and error.
  Future<void> _run(String key, Future<void> Function() refine) async {
    void update(void Function() change) {
      if (!mounted) return;
      setState(change);
      _tick.value++;
    }

    update(() {
      _busy.add(key);
      _errors.remove(key);
    });
    try {
      await refine();
    } catch (e) {
      update(() => _errors[key] = 'AI refinement failed: $e');
    } finally {
      update(() => _busy.remove(key));
    }
  }

  AiSettings? get _settings {
    final settings = ref.read(aiSettingsProvider).valueOrNull;
    return settings != null && canRunFuelAi(settings) ? settings : null;
  }

  Future<void> _refineFuel(FuelForecast forecast) async {
    final settings = _settings;
    if (settings == null) return;
    final estimate = await estimateFuelWithAi(
      settings: settings,
      forecast: forecast,
      transactions: ref.read(expensesSummaryProvider).transactions,
      activities: ref.read(locationSummaryProvider).activities,
      events: ref.read(calendarSummaryProvider).events,
    );
    await ref.read(fuelAiEstimateProvider.notifier).save(estimate);
  }

  /// The user's ride from personal information, else their lifestyle text,
  /// which may mention it.
  String _rideContext() {
    final config = ref.read(promptConfigProvider).valueOrNull;
    final ride = config?.ride.trim() ?? '';
    return ride.isNotEmpty ? ride : (config?.householdLifestyle ?? '');
  }

  Future<void> _refineOutlook(Set<OutlookSection> sections) async {
    final settings = _settings;
    if (settings == null) return;
    final p = widget.predictions;
    final estimate = await estimateOutlookWithAi(
      settings: settings,
      events: ref.read(calendarSummaryProvider).events,
      bills: p.upcomingCharges,
      currency: p.currency,
      monthPace: p.monthPace,
      budget: p.budget,
      payday: p.payday,
      bike: p.bikeService,
      oil: p.bikeOil,
      rideContext: _rideContext(),
      history: ref.read(expensesForAnalysisProvider).history,
      transactions: ref.read(expensesSummaryProvider).transactions,
      spending: ref.read(expensesHistoryProvider).transactions,
      activities: ref.read(locationSummaryProvider).activities,
      sections: sections,
    );
    await ref.read(outlookAiEstimateProvider.notifier).save(estimate);
  }

  /// Sends the raw rows behind [forecasts] and stores the AI's own answers.
  Future<void> _refineLife(List<LifeForecast> forecasts) async {
    final settings = _settings;
    if (settings == null || forecasts.isEmpty) return;
    final estimate = await estimateLifeWithAi(
      settings: settings,
      forecasts: forecasts,
    );
    await ref.read(lifeAiEstimateProvider.notifier).save(estimate);
  }

  /// Refines every prediction that has something to refine.
  Future<void> _refineAll() async {
    final p = widget.predictions;
    final sections = <OutlookSection>{
      if (p.upcomingCharges.isNotEmpty) OutlookSection.bills,
      if (p.budget != null) OutlookSection.budget,
      if (p.payday != null) OutlookSection.payday,
      if (p.monthPace != null) OutlookSection.monthEnd,
      if (p.bikeService != null) OutlookSection.bike,
      if (p.bikeOil != null) OutlookSection.oil,
    };
    final fuel = p.fuel;
    await _run(
      'all',
      () => Future.wait([
        if (fuel != null) _refineFuel(fuel),
        if (sections.isNotEmpty) _refineOutlook(sections),
        if (p.life.isNotEmpty) _refineLife(p.life),
      ]),
    );
  }

  /// The full panel for one prediction, with its AI refine controls.
  Widget? _panel(String key) {
    final p = widget.predictions;
    final money = NumberFormat.currency(
      symbol: currencyPrefix(p.currency),
      decimalDigits: 0,
    );
    final aiSettings = ref.watch(aiSettingsProvider).valueOrNull;
    final canRefine = aiSettings != null && canRunFuelAi(aiSettings);
    final fuelAi = ref.watch(fuelAiEstimateProvider);
    final outlookAi = ref.watch(outlookAiEstimateProvider);

    VoidCallback? refine(Future<void> Function() action) =>
        canRefine ? () => _run(key, action) : null;
    VoidCallback? refineOutlook(OutlookSection section) =>
        refine(() => _refineOutlook({section}));

    final life = p.life.where((f) => f.key == key).firstOrNull;
    if (life != null) {
      return LifeForecastPanel(
        forecast: life,
        ai: ref.watch(lifeAiEstimateProvider)?.items[key],
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refine(() => _refineLife([life])),
      );
    }

    return switch (key) {
      'fuel' when p.fuel != null => FuelForecastPanel(
        forecast: p.fuel!,
        money: money,
        aiEstimate: fuelAi,
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refine(() => _refineFuel(p.fuel!)),
      ),
      'bills' when p.upcomingCharges.isNotEmpty => UpcomingChargesPanel(
        charges: p.upcomingCharges,
        money: money,
        ai: outlookAi,
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refineOutlook(OutlookSection.bills),
      ),
      'budget' when p.budget != null => MoneyOutlookPanel(
        money: money,
        budget: p.budget,
        ai: outlookAi,
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refineOutlook(OutlookSection.budget),
      ),
      'payday' when p.payday != null => MoneyOutlookPanel(
        money: money,
        payday: p.payday,
        ai: outlookAi,
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refineOutlook(OutlookSection.payday),
      ),
      'month' when p.monthPace != null => MonthPacePanel(
        projection: p.monthPace!,
        money: money,
        ai: outlookAi,
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refineOutlook(OutlookSection.monthEnd),
      ),
      'bike' when p.bikeService != null => BikeServicePanel(
        forecast: p.bikeService!,
        ai: outlookAi,
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refineOutlook(OutlookSection.bike),
      ),
      'oil' when p.bikeOil != null => BikeServicePanel(
        forecast: p.bikeOil!,
        ai: outlookAi,
        aiBusy: _busy.contains(key),
        aiError: _errors[key],
        onRefineWithAi: refineOutlook(OutlookSection.oil),
      ),
      _ => null,
    };
  }

  void _openDetail(PredictionCardData card) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) => ValueListenableBuilder<int>(
          valueListenable: _tick,
          builder: (context, _, _) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              0,
              AppSpacing.screen,
              AppSpacing.screen + MediaQuery.paddingOf(context).bottom,
            ),
            child: _panel(card.key) ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.predictions;
    final money = NumberFormat.currency(
      symbol: currencyPrefix(p.currency),
      decimalDigits: 0,
    );
    final aiSettings = ref.watch(aiSettingsProvider).valueOrNull;
    final canRefine = aiSettings != null && canRunFuelAi(aiSettings);
    final cards = buildPredictionCards(
      context,
      p,
      money: money,
      fuelAi: ref.watch(fuelAiEstimateProvider),
      outlookAi: ref.watch(outlookAiEstimateProvider),
      lifeAi: ref.watch(lifeAiEstimateProvider),
    );
    final refiningAll = _busy.contains('all');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('PREDICTIONS', style: context.sectionLabel)),
            IconButton(
              tooltip: 'Choose predictions',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.tune_rounded, size: 20),
              onPressed: () => showPredictionChooser(
                context,
                shownKeys: {for (final c in cards) c.key},
              ),
            ),
            if (canRefine && cards.isNotEmpty)
              TextButton.icon(
                onPressed: refiningAll ? null : _refineAll,
                icon: refiningAll
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('Refine all with AI'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        PredictionList(cards: cards, busyKeys: _busy, onOpen: _openDetail),
      ],
    );
  }
}
