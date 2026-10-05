import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:personal/app/router.dart';
import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/core/theme/theme_mode_controller.dart';
import 'package:personal/features/onboarding/onboarding_screen.dart';
import 'package:personal/features/settings/settings_status.dart';
import 'package:personal/shared/widgets/app_card.dart';
import 'package:personal/shared/widgets/app_screen_app_bar.dart';
import 'package:personal/shared/widgets/content_width.dart';

/// Every settings area in one place, each row showing its current state.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(settingsStatusProvider);
    final backup = ref.watch(backupInfoProvider).valueOrNull;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    final storageText = backup == null
        ? status.storage.text
        : '${status.storage.text} · backed up '
              '${DateFormat('d MMM').format(backup.createdAt.toLocal())}';

    final groups = <_Group>[
      _Group('Data', [
        _Entry(
          icon: Icons.folder_outlined,
          title: 'Storage & backup',
          status: StatusLine(storageText, status.storage.tone),
          route: AppRoutes.generalSettings,
          section: 'storage',
          keywords: 'folder data reports backup restore export',
        ),
        _Entry(
          icon: Icons.monitor_heart_outlined,
          title: 'Health sources',
          status: const StatusLine(
            'Health Connect permissions',
            StatusTone.neutral,
          ),
          route: AppRoutes.healthSettings,
          keywords: 'health connect samsung sleep permissions',
        ),
      ]),
      _Group('Intelligence', [
        _Entry(
          icon: Icons.auto_awesome_outlined,
          title: 'AI provider',
          status: status.ai,
          route: AppRoutes.generalSettings,
          section: 'ai',
          keywords: 'openai gemini claude anthropic key model api',
        ),
        _Entry(
          icon: Icons.person_outline,
          title: 'Personal information',
          status: status.profile,
          route: AppRoutes.personalInformation,
          keywords: 'profile income budget goals job name age',
        ),
        _Entry(
          icon: Icons.tune_outlined,
          title: 'System prompt',
          status: const StatusLine('Read-only template', StatusTone.neutral),
          route: AppRoutes.prompts,
          keywords: 'prompt assistant tone rules output',
        ),
      ]),
      _Group('Account & alerts', [
        _Entry(
          icon: Icons.account_circle_outlined,
          title: 'Google account',
          status: status.account,
          route: AppRoutes.calendarSettings,
          keywords: 'google sign in calendar sync firebase profile',
        ),
        _Entry(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          status: const StatusLine(
            'Month-end & weekly reminders',
            StatusTone.neutral,
          ),
          route: AppRoutes.generalSettings,
          section: 'notifications',
          keywords: 'reminder alert weekly month end notify',
        ),
      ]),
    ];

    final query = _query.trim().toLowerCase();
    bool matches(_Entry e) =>
        query.isEmpty ||
        '${e.title} ${e.status.text} ${e.keywords}'.toLowerCase().contains(
          query,
        );
    final visible = [
      for (final g in groups)
        _Group(g.title, g.entries.where(matches).toList()),
    ].where((g) => g.entries.isNotEmpty).toList();

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
                    for (var i = 0; i < group.entries.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          indent: 68,
                          color: context.palette.border,
                        ),
                      _SettingsRow(entry: group.entries[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            if (query.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.sm),
                child: Text('APPEARANCE & HELP', style: context.sectionLabel),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: const Text('Dark theme'),
                      value: isDark,
                      onChanged: (value) => ref
                          .read(themeModeProvider.notifier)
                          .setDarkMode(value),
                    ),
                    Divider(height: 1, color: context.palette.border),
                    ListTile(
                      leading: const Icon(Icons.waving_hand_outlined),
                      title: const Text('Replay the walkthrough'),
                      subtitle: const Text('Folder, profile and AI key setup'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const OnboardingScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Group {
  const _Group(this.title, this.entries);

  final String title;
  final List<_Entry> entries;
}

class _Entry {
  const _Entry({
    required this.icon,
    required this.title,
    required this.status,
    required this.route,
    this.section,
    this.keywords = '',
  });

  final IconData icon;
  final String title;
  final StatusLine status;
  final String route;

  /// Which part of the target screen to scroll to.
  final String? section;
  final String keywords;
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tone = switch (entry.status.tone) {
      StatusTone.ok => palette.accent,
      StatusTone.warning => palette.warning,
      StatusTone.neutral => palette.textMuted,
    };

    return Semantics(
      button: true,
      label:
          '${entry.title}. ${entry.status.text}'
          '${entry.status.tone == StatusTone.warning ? '. Needs attention' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () =>
            Navigator.pushNamed(context, entry.route, arguments: entry.section),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: AppOpacity.medium),
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(entry.icon, size: 20, color: tone),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (entry.status.tone != StatusTone.neutral) ...[
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
                            entry.status.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: entry.status.tone == StatusTone.warning
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
