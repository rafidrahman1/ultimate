import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/formatting.dart';
import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/features/ai/ai_client.dart';
import 'package:motohealth/features/ai/ai_settings.dart';
import 'package:motohealth/features/ai/ai_settings_screen.dart';
import 'package:motohealth/features/ai/schedule_plan.dart';
import 'package:motohealth/features/garage/bike_form.dart';
import 'package:motohealth/features/garage/maintenance_catalog.dart';
import 'package:motohealth/features/garage/moto_logic.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';

/// Asks the AI which jobs from the built-in maintenance catalog belong on this
/// exact bike, shows its choice for review, and applies what the rider keeps.
class ScheduleAiScreen extends ConsumerStatefulWidget {
  const ScheduleAiScreen({super.key, required this.bikeId});

  final String bikeId;

  @override
  ConsumerState<ScheduleAiScreen> createState() => _ScheduleAiScreenState();
}

enum _Phase { needsDetails, needsKey, loading, review, error }

class _ScheduleAiScreenState extends ConsumerState<ScheduleAiScreen> {
  _Phase _phase = _Phase.loading;
  SchedulePlan? _plan;
  String _error = '';
  final _selected = <String>{};
  bool? _replace;
  AiCancelToken? _token;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  Bike? get _bike => ref
      .read(motoStoreProvider)
      .valueOrNull
      ?.bikes
      .where((b) => b.id == widget.bikeId)
      .firstOrNull;

  Future<void> _start() async {
    final bike = _bike;
    if (bike == null) return;
    if (missingBikeDetails(bike).isNotEmpty) {
      setState(() => _phase = _Phase.needsDetails);
      return;
    }
    final settings = await ref.read(aiSettingsProvider.future);
    if (!mounted) return;
    if (!settings.isConfigured) {
      setState(() => _phase = _Phase.needsKey);
      return;
    }
    setState(() => _phase = _Phase.loading);
    final data = ref.read(motoStoreProvider).requireValue;
    final token = _token = AiCancelToken();
    try {
      final text = await aiClient.generate(
        settings: settings,
        system: scheduleSystemPrompt,
        prompt: buildSchedulePrompt(bike, latestOdometer(data, bike)),
        webSearch: true,
        cancelToken: token,
      );
      final plan = parseSchedulePlan(text);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _selected
          ..clear()
          ..addAll(plan.pickedIds);
        _phase = _Phase.review;
      });
    } on AiCancelledException {
      return;
    } on FormatException {
      _fail(
        'The AI answered in a form the app could not read. Try again, or '
        'pick a stronger model in AI settings.',
      );
    } catch (error) {
      _fail(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _phase = _Phase.error;
    });
  }

  Future<void> _apply() async {
    final bike = _bike;
    final plan = _plan;
    if (bike == null || plan == null) return;
    final data = ref.read(motoStoreProvider).requireValue;
    final history = tasksWithHistory(data, bike);
    final replace = _replace ?? history.isEmpty;
    final tasks = applySelection(
      bike,
      _selected,
      replace: replace,
      withHistory: history,
    );
    await ref
        .read(motoStoreProvider.notifier)
        .updateBike(bike.copyWith(tasks: tasks));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maintenance list updated (${tasks.length} jobs)'),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bike = ref
        .watch(motoStoreProvider)
        .valueOrNull
        ?.bikes
        .where((b) => b.id == widget.bikeId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('AI maintenance plan')),
      body: ContentWidth(
        child: switch (_phase) {
          _Phase.loading => _Loading(bike: bike),
          _Phase.needsDetails => _Message(
            icon: Icons.edit_note_rounded,
            title: 'I need to know your bike',
            body:
                'Add the make, model and year (and engine size and variant if '
                'you know them) so the plan matches your exact bike.',
            action: 'Edit bike',
            onAction: () async {
              if (bike != null) await showBikeForm(context, bike: bike);
              if (mounted) unawaited(_start());
            },
          ),
          _Phase.needsKey => _Message(
            icon: Icons.key_rounded,
            title: 'Set up AI first',
            body:
                'Add an API key for OpenAI, Gemini or Claude. It stays on '
                'this phone.',
            action: 'AI settings',
            onAction: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AiSettingsScreen(),
                ),
              );
              if (mounted) unawaited(_start());
            },
          ),
          _Phase.error => _Message(
            icon: Icons.error_outline_rounded,
            title: 'Could not build the plan',
            body: _error,
            action: 'Try again',
            onAction: _start,
          ),
          _Phase.review => _review(context, bike),
        },
      ),
    );
  }

  Widget _review(BuildContext context, Bike? bike) {
    final plan = _plan!;
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final theme = Theme.of(context);
    final palette = context.palette;
    final history = bike == null ? <String>{} : tasksWithHistory(data, bike);
    final replace = _replace ?? history.isEmpty;
    final have = {
      for (final t in bike?.tasks ?? const <ServiceTask>[]) t.id: t,
    };
    final others = [
      for (final i in maintenanceCatalog)
        if (!plan.pickedIds.contains(i.id)) i,
    ];

    Color confColor(Confidence c) => switch (c) {
      Confidence.high => palette.statusGood,
      Confidence.medium => palette.warning,
      Confidence.low => palette.statusCritical,
    };

    void toggle(String id, bool on) =>
        setState(() => on ? _selected.add(id) : _selected.remove(id));

    String intervalOf(CatalogItem i) {
      final t = have[i.id];
      return _interval(t?.intervalKm ?? i.km, t?.intervalDays ?? i.days);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.xxl,
      ),
      children: [
        AppCard(
          tier: AppCardTier.hero,
          accent: confColor(plan.confidence),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chosen for', style: context.sectionLabel),
              const SizedBox(height: 2),
              Text(
                plan.identified.isEmpty
                    ? (bike?.fullName ?? '')
                    : plan.identified,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Confidence: ${plan.confidence.label}. Check this is your '
                'machine before applying.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: confColor(plan.confidence),
                  fontWeight: FontWeight.w700,
                ),
              ),
              for (final a in plan.assumptions)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Assumed: $a', style: theme.textTheme.bodySmall),
                ),
              for (final w in plan.warnings)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Note: $w',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.warning,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'The AI only picks which jobs apply; intervals come from the '
          "catalog and you can edit them. Jobs marked Low are guesses, so "
          "check them against your owner's manual.",
          style: theme.textTheme.bodySmall?.copyWith(color: palette.textMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Recommended (${plan.picks.length})', style: context.sectionLabel),
        const SizedBox(height: AppSpacing.sm),
        for (final p in plan.picks)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(4, 8, 14, 12),
              onTap: () => toggle(p.item.id, !_selected.contains(p.item.id)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _selected.contains(p.item.id),
                    onChanged: (v) => toggle(p.item.id, v == true),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.item.name,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                p.confidence.label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: confColor(p.confidence),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            intervalOf(p.item),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (p.reason.isNotEmpty)
                            Text(
                              p.reason,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Not chosen (${others.length})',
              style: context.sectionLabel,
            ),
            subtitle: const Text('Tick any you want on the list anyway'),
            children: [
              for (final i in others)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(i.name),
                  subtitle: Text('${intervalOf(i)} · ${i.hint}'),
                  value: _selected.contains(i.id),
                  onChanged: (v) => toggle(i.id, v == true),
                ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remove the other catalog jobs'),
          subtitle: Text(
            history.isEmpty
                ? 'Jobs that are not ticked leave your list.'
                : 'Jobs that are not ticked leave your list, except those '
                      'with service history.',
          ),
          value: replace,
          onChanged: (v) => setState(() => _replace = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: _selected.isEmpty ? null : _apply,
          icon: const Icon(Icons.check_rounded),
          label: Text('Apply ${_selected.length} jobs'),
        ),
      ],
    );
  }

  String _interval(double? km, int? days) => [
    if (km != null) 'every ${formatKm(km)}',
    if (days != null) 'every $days days',
  ].join(' or ');
}

class _Loading extends StatelessWidget {
  const _Loading({this.bike});

  final Bike? bike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Working out which maintenance jobs fit\n'
              '${bike?.fullName ?? 'your bike'}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This can take up to a minute while it checks published '
              'schedules.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: context.palette.textMuted),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
