import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/app_info/app_info.dart';
import 'package:personal/core/app_info/app_info_provider.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/theme/theme_mode_controller.dart';
import 'package:personal/features/app_update/app_update_dialog.dart';
import 'package:personal/features/app_update/app_update_service.dart';
import 'package:personal/features/game_activity/data/game_cover_service.dart';
import 'package:personal/features/onboarding/onboarding_screen.dart';
import 'package:personal/features/settings/settings_status.dart';
import 'package:personal/features/weather/data/weather_service.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';

/// Every settings area in one place, grouped by what it is for. Rows that
/// lead somewhere show their live state; simple on/off options switch in
/// place. Everything is searchable.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _query = '';

  void _go(String route, [SettingsSection? section]) =>
      Navigator.pushNamed(context, route, arguments: section);

  Future<void> _checkForUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking for updates...')),
    );
    try {
      final service = AppUpdateService();
      final update = await service.checkForUpdate();
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      if (update == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('You are on the latest version.')),
        );
      } else {
        await showAppUpdateDialog(context, service, update);
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to check for updates: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(settingsStatusProvider);
    final themeMode = ref.watch(themeModeProvider);
    final covers = ref.watch(gameCoversEnabledProvider).value ?? false;
    final weather = ref.watch(weatherEnabledProvider);
    final version = ref
        .watch(packageInfoProvider)
        .maybeWhen(
          data: (info) => 'v${info.version} (${info.buildNumber})',
          orElse: () => null,
        );

    final groups = <_Group>[
      _Group('You', [
        _Item.link(
          icon: Icons.person_outline,
          title: 'Personal information',
          status: status.profile,
          keywords: 'profile income budget goals job name age ride weekend',
          onTap: () => _go(AppRoutes.personalInformation),
        ),
        _Item.link(
          icon: Icons.account_circle_outlined,
          title: 'Google account',
          status: status.account,
          keywords:
              'google sign in calendar sync firebase profile drive files '
              'folder timeline cashew backup restore export',
          onTap: () => _go(AppRoutes.calendarSettings),
        ),
      ]),
      _Group('AI', [
        _Item.link(
          icon: Icons.auto_awesome_outlined,
          title: 'AI provider',
          status: status.ai,
          keywords: 'openai gemini claude anthropic key model api refine',
          onTap: () => _go(AppRoutes.generalSettings, SettingsSection.ai),
        ),
      ]),
      _Group('Data sources', [
        _Item.link(
          icon: Icons.monitor_heart_outlined,
          title: 'Health Connect',
          status: const StatusLine(
            'Sleep, steps and vitals permissions',
            StatusTone.neutral,
          ),
          keywords: 'health connect samsung sleep permissions steps heart',
          onTap: () => _go(AppRoutes.healthSettings),
        ),
        _Item.link(
          icon: Icons.radar_rounded,
          title: 'Location timeline',
          status: const StatusLine(
            'Record my timeline · Google Drive',
            StatusTone.neutral,
          ),
          keywords: 'location record timeline gps drive backup places trips',
          onTap: () => _go(AppRoutes.locationSettings),
        ),
        _Item.toggle(
          icon: Icons.image_outlined,
          title: 'Game cover art',
          subtitle: 'Looks up titles on Steam, then Wikipedia',
          keywords: 'game cover steam wikipedia art images privacy',
          value: covers,
          onChanged: (on) =>
              ref.read(gameCoversEnabledProvider.notifier).set(on),
        ),
        _Item.toggle(
          icon: Icons.cloud_outlined,
          title: 'Weather in predictions',
          subtitle: 'Open-Meteo forecast for your home area (~11 km)',
          keywords: 'weather forecast open meteo rain privacy',
          value: weather,
          onChanged: (on) => ref.read(weatherEnabledProvider.notifier).set(on),
        ),
      ]),
      _Group('Reminders', [
        _Item.link(
          icon: Icons.notifications_outlined,
          title: 'Reminders & alerts',
          status: const StatusLine(
            'Check-ins, commute, prediction calendar',
            StatusTone.neutral,
          ),
          keywords:
              'notification reminder alert prediction bill refuel notify '
              'check in commute calendar exact alarm battery',
          onTap: () =>
              _go(AppRoutes.generalSettings, SettingsSection.notifications),
        ),
      ]),
      _Group('Appearance', [
        _Item(
          title: 'Theme',
          keywords: 'appearance theme dark light mode auto system',
          builder: (context) => _ThemeRow(
            mode: themeMode,
            onChanged: (mode) =>
                ref.read(themeModeProvider.notifier).setMode(mode),
          ),
        ),
      ]),
      _Group('Help & about', [
        _Item.link(
          icon: Icons.waving_hand_outlined,
          title: 'Replay the walkthrough',
          status: const StatusLine(
            'Profile and AI key setup',
            StatusTone.neutral,
          ),
          keywords: 'onboarding walkthrough intro tutorial',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const OnboardingScreen()),
          ),
        ),
        if (Platform.isAndroid)
          _Item.link(
            icon: Icons.system_update_outlined,
            title: 'Check for updates',
            status: StatusLine(
              version == null
                  ? 'From GitHub releases'
                  : 'Installed $version · GitHub releases',
              StatusTone.neutral,
            ),
            keywords: 'update version release github install',
            onTap: _checkForUpdates,
          ),
        _Item.link(
          icon: Icons.receipt_long_outlined,
          title: 'Diagnostics log',
          status: const StatusLine(
            'Warnings and failed requests, on this device only',
            StatusTone.neutral,
          ),
          keywords: 'diagnostics log debug error warning',
          onTap: () => _go(AppRoutes.diagnosticsLog),
        ),
      ]),
    ];

    final query = _query.trim().toLowerCase();
    final visible = [
      for (final g in groups)
        _Group(g.title, [
          for (final item in g.items)
            if (query.isEmpty ||
                '${g.title} ${item.title} ${item.keywords}'
                    .toLowerCase()
                    .contains(query))
              item,
        ]),
    ].where((g) => g.items.isNotEmpty).toList();
    final toFix = status.warningCount;

    return Scaffold(
      appBar: AppScreenAppBar.build(context, ref, title: 'Settings'),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            AppSpacing.md,
            AppSpacing.screen,
            AppSpacing.xxl,
          ),
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search settings',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
            if (query.isEmpty && toFix > 0) ...[
              const SizedBox(height: AppSpacing.md),
              _AttentionBanner(count: toFix),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'No settings match "$_query".',
                    style: TextStyle(color: context.palette.textMuted),
                  ),
                ),
              ),
            for (final group in visible) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
                child: Text(
                  group.title.toUpperCase(),
                  style: context.sectionLabel,
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < group.items.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 68,
                          color: context.palette.border,
                        ),
                      group.items[i].builder(context),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (query.isEmpty)
              Center(
                child: Text(
                  version == null
                      ? AppInfo.displayName
                      : '${AppInfo.displayName} $version',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.palette.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Group {
  const _Group(this.title, this.items);

  final String title;
  final List<_Item> items;
}

/// One searchable row.
class _Item {
  const _Item({required this.title, required this.builder, this.keywords = ''});

  /// A row that opens another screen, with its live status line.
  factory _Item.link({
    required IconData icon,
    required String title,
    required StatusLine status,
    required VoidCallback onTap,
    String keywords = '',
  }) => _Item(
    title: title,
    keywords: '${status.text} $keywords',
    builder: (_) =>
        _LinkRow(icon: icon, title: title, status: status, onTap: onTap),
  );

  /// An on/off option that switches in place.
  factory _Item.toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String keywords = '',
  }) => _Item(
    title: title,
    keywords: '$subtitle $keywords',
    builder: (_) => _ToggleRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: value,
      onChanged: onChanged,
    ),
  );

  final String title;
  final String keywords;
  final WidgetBuilder builder;
}

/// Tinted square holding a row's icon.
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon, this.color);

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final StatusLine status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tone = switch (status.tone) {
      StatusTone.ok => palette.accent,
      StatusTone.warning => palette.warning,
      StatusTone.neutral => palette.textMuted,
    };

    return Semantics(
      button: true,
      label:
          '$title. ${status.text}'
          '${status.tone == StatusTone.warning ? '. Needs attention' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              _RowIcon(icon, tone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (status.tone != StatusTone.neutral) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: tone,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            status.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: status.tone == StatusTone.warning
                                  ? palette.warning
                                  : palette.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              _RowIcon(icon, value ? palette.accent : palette.textMuted),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _RowIcon(Icons.brightness_6_outlined, palette.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}

/// "2 things need attention", shown above the groups while setup is
/// incomplete.
class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: AppOpacity.subtle),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: palette.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              count == 1
                  ? '1 setting needs attention — marked below.'
                  : '$count settings need attention — marked below.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.warning),
            ),
          ),
        ],
      ),
    );
  }
}
