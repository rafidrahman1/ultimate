import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/core/formatting.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/features/analysis/analysis_view_providers.dart';
import 'package:personal/features/calendar/calendar_service.dart';
import 'package:personal/features/dashboard/predictions_provider.dart';
import 'package:personal/features/expenses/expense_panels.dart';
import 'package:personal/features/expenses/expenses_service.dart';
import 'package:personal/features/expenses/fuel_forecast.dart';
import 'package:personal/features/expenses/fuel_forecast_ai.dart';
import 'package:personal/features/expenses/fuel_forecast_ai_service.dart';
import 'package:personal/features/expenses/outlook_ai.dart';
import 'package:personal/features/expenses/outlook_ai_service.dart';
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

  /// Runs one prediction's refinement, with its own busy flag and error.
  Future<void> _run(String key, Future<void> Function() refine) async {
    setState(() {
      _busy.add(key);
      _errors.remove(key);
    });
    try {
      await refine();
    } catch (e) {
      if (mounted) setState(() => _errors[key] = 'AI refinement failed: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(key));
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
      sections: sections,
    );
    await ref.read(outlookAiEstimateProvider.notifier).save(estimate);
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
    final fuel = p.fuel;
    final fuelAi = ref.watch(fuelAiEstimateProvider);
    final outlookAi = ref.watch(outlookAiEstimateProvider);

    VoidCallback? refine(String key, Future<void> Function() action) =>
        canRefine ? () => _run(key, action) : null;
    VoidCallback? refineOutlook(String key, OutlookSection section) =>
        refine(key, () => _refineOutlook({section}));

    final panels = <Widget>[
      if (fuel != null)
        FuelForecastPanel(
          forecast: fuel,
          money: money,
          aiEstimate: fuelAi,
          aiBusy: _busy.contains('fuel'),
          aiError: _errors['fuel'],
          onRefineWithAi: refine('fuel', () => _refineFuel(fuel)),
        ),
      if (p.upcomingCharges.isNotEmpty)
        UpcomingChargesPanel(
          charges: p.upcomingCharges,
          money: money,
          ai: outlookAi,
          aiBusy: _busy.contains('bills'),
          aiError: _errors['bills'],
          onRefineWithAi: refineOutlook('bills', OutlookSection.bills),
        ),
      if (p.budget != null)
        MoneyOutlookPanel(
          money: money,
          budget: p.budget,
          ai: outlookAi,
          aiBusy: _busy.contains('budget'),
          aiError: _errors['budget'],
          onRefineWithAi: refineOutlook('budget', OutlookSection.budget),
        ),
      if (p.payday != null)
        MoneyOutlookPanel(
          money: money,
          payday: p.payday,
          ai: outlookAi,
          aiBusy: _busy.contains('payday'),
          aiError: _errors['payday'],
          onRefineWithAi: refineOutlook('payday', OutlookSection.payday),
        ),
      if (p.monthPace != null)
        MonthPacePanel(
          projection: p.monthPace!,
          money: money,
          ai: outlookAi,
          aiBusy: _busy.contains('month'),
          aiError: _errors['month'],
          onRefineWithAi: refineOutlook('month', OutlookSection.monthEnd),
        ),
      if (p.bikeService != null)
        BikeServicePanel(
          forecast: p.bikeService!,
          ai: outlookAi,
          aiBusy: _busy.contains('bike'),
          aiError: _errors['bike'],
          onRefineWithAi: refineOutlook('bike', OutlookSection.bike),
        ),
      if (p.bikeOil != null)
        BikeServicePanel(
          forecast: p.bikeOil!,
          ai: outlookAi,
          aiBusy: _busy.contains('oil'),
          aiError: _errors['oil'],
          onRefineWithAi: refineOutlook('oil', OutlookSection.oil),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PREDICTIONS', style: context.sectionLabel),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < panels.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          panels[i],
        ],
      ],
    );
  }
}
