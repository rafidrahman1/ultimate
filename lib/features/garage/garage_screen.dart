import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/core/theme/theme_mode_controller.dart';
import 'package:motohealth/features/ai/ai_settings.dart';
import 'package:motohealth/features/ai/ai_settings_screen.dart';
import 'package:motohealth/features/garage/backup.dart';
import 'package:motohealth/features/garage/bike_form.dart';
import 'package:motohealth/features/garage/currencies.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/features/garage/schedule_screen.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

String _currencyLabel(MotoData data) {
  final c = currencyByCode(data.currencyCode);
  return c == null ? data.currency : '${c.name} (${c.code}) · ${c.symbol}';
}

Future<void> _pickCurrency(
  BuildContext context,
  WidgetRef ref,
  MotoData data,
) async {
  final picked = await showModalBottomSheet<Currency>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _CurrencyList(selected: data.currencyCode),
  );
  if (picked != null) {
    await ref.read(motoStoreProvider.notifier).setCurrency(picked);
  }
}

class _CurrencyList extends StatefulWidget {
  const _CurrencyList({required this.selected});

  final String? selected;

  @override
  State<_CurrencyList> createState() => _CurrencyListState();
}

class _CurrencyListState extends State<_CurrencyList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final c in currencies)
        if (q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q))
          c,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search currency',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final c = shown[i];
                return ListTile(
                  title: Text(c.name),
                  subtitle: Text(c.code),
                  trailing: Text(c.symbol),
                  selected: c.code == widget.selected,
                  onTap: () => Navigator.pop(context, c),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Bikes, their maintenance schedules, and app settings.
class GarageScreen extends ConsumerWidget {
  const GarageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(motoStoreProvider).valueOrNull ?? const MotoData();
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Garage')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showBikeForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add bike'),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.sm,
            AppSpacing.screen,
            96,
          ),
          children: [
            Text('Bikes', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            for (final bike in data.bikes) ...[
              AppCard(
                tier: bike.id == data.selectedBike?.id
                    ? AppCardTier.hero
                    : AppCardTier.raised,
                accent: palette.mobility,
                onTap: () {
                  ref.read(motoStoreProvider.notifier).selectBike(bike.id);
                  Navigator.pop(context);
                },
                child: Row(
                  children: [
                    Icon(Icons.two_wheeler_rounded, color: palette.mobility),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bike.name, style: theme.textTheme.titleMedium),
                          if (bike.subtitle.isNotEmpty)
                            Text(
                              bike.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: palette.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Maintenance schedule',
                      icon: const Icon(Icons.build_circle_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ScheduleScreen(bikeId: bike.id),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => showBikeForm(context, bike: bike),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok = await confirmDelete(
                          context,
                          '${bike.name} and all its records',
                        );
                        if (ok) {
                          await ref
                              .read(motoStoreProvider.notifier)
                              .deleteBike(bike.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (data.bikes.isEmpty)
              Text(
                'No bikes yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text('AI assistant', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AiSettingsScreen(),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: palette.accent),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI settings', style: theme.textTheme.titleSmall),
                        Text(
                          ref
                                      .watch(aiSettingsProvider)
                                      .valueOrNull
                                      ?.isConfigured ==
                                  true
                              ? 'Ready: ${ref.watch(aiSettingsProvider).requireValue.provider.label}'
                              : 'Add an API key to build maintenance plans and run analysis',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Settings', style: context.sectionLabel),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.card),
                    onTap: () => _pickCurrency(context, ref, data),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Currency',
                        suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                      ),
                      child: Text(_currencyLabel(data)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Backup', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Your data lives only on this phone and is lost if the '
                    'app is uninstalled or its data cleared. Save a copy now '
                    'and then.\n'
                    '${data.lastBackup == null ? 'Never backed up.' : 'Last backup: ${DateFormat('d MMM yyyy').format(data.lastBackup!)}.'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => saveBackup(context, ref, data),
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => shareBackup(context, ref, data),
                          icon: const Icon(Icons.ios_share_rounded),
                          label: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => importBackup(context, ref),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Restore from a backup file'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Appearance', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('Auto'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).setMode(s.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Your data is stored on this phone, with no account. The only '
              'network use is the AI features, which send a bike\'s records '
              'to the provider you chose.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
