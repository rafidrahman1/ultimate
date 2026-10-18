import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:motohealth/core/theme/app_theme.dart';
import 'package:motohealth/core/theme/theme_mode_controller.dart';
import 'package:motohealth/features/ai/ai_settings.dart';
import 'package:motohealth/features/ai/ai_settings_screen.dart';
import 'package:motohealth/features/garage/bike_form.dart';
import 'package:motohealth/features/garage/moto_models.dart';
import 'package:motohealth/features/garage/moto_store.dart';
import 'package:motohealth/features/garage/schedule_screen.dart';
import 'package:motohealth/shared/widgets/app_card.dart';
import 'package:motohealth/shared/widgets/content_width.dart';
import 'package:motohealth/shared/widgets/form_bits.dart';

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
                  TextFormField(
                    initialValue: data.currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency symbol',
                      helperText: r'Shown before amounts, e.g. $, ৳, ₹, £',
                    ),
                    onChanged: (v) => ref
                        .read(motoStoreProvider.notifier)
                        .setCurrency(v.trim()),
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
