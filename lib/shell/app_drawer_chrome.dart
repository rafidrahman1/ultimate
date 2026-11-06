part of 'app_drawer.dart';

class _DrawerFooter extends ConsumerWidget {
  const _DrawerFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final versionLabel = ref
        .watch(packageInfoProvider)
        .maybeWhen(data: (info) => info.version, orElse: () => null);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(color: palette.border, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  versionLabel == null
                      ? AppInfo.displayName
                      : '${AppInfo.displayName} · v$versionLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.textMuted,
                  ),
                ),
              ),
              IconButton(
                tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
                onPressed: () => ref
                    .read(themeModeProvider.notifier)
                    .toggle(theme.brightness),
                icon: Icon(
                  isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DrawerProfileHeader extends StatelessWidget {
  const _DrawerProfileHeader({
    required this.userTitle,
    required this.profilePhotoUrl,
  });

  final String userTitle;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.accent.withValues(alpha: 0.14),
            palette.accent.withValues(alpha: 0.02),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxl,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: palette.accent.withValues(alpha: 0.16),
                  foregroundImage: profilePhotoUrl != null
                      ? ResizeImage(NetworkImage(profilePhotoUrl!), width: 168)
                      : null,
                  onForegroundImageError: profilePhotoUrl != null
                      ? (_, _) {}
                      : null,
                  child: Icon(Icons.person, color: palette.accent, size: 30),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Personal Dashboard',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(
                        alpha: AppOpacity.medium,
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      child: Text(
                        AppInfo.displayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain-language statement of where data goes, driven by the live AI and
/// Google settings so it never overstates "local".
class _DrawerPrivacyCard extends StatelessWidget {
  const _DrawerPrivacyCard({
    required this.aiProviderLabel,
    required this.googleConnected,
    required this.onTap,
  });

  /// Null when AI requests are off.
  final String? aiProviderLabel;
  final bool googleConnected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final aiOn = aiProviderLabel != null;

    final title = aiOn
        ? 'Shared only when AI runs'
        : 'Your data stays on this device';
    final body = [
      'Imported data is processed on this device.',
      aiOn
          ? 'AI requests send selected information to $aiProviderLabel.'
          : 'AI is off, so nothing goes to a provider.',
      if (googleConnected) 'Calendar sync uses your Google account.',
    ].join(' ');

    return Semantics(
      button: true,
      label: '$title. $body Opens AI settings.',
      excludeSemantics: true,
      child: Material(
        color: palette.statusGood.withValues(alpha: AppOpacity.subtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.cardLarge),
          side: BorderSide(color: palette.statusGood.withValues(alpha: 0.28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 22,
                  color: palette.statusGood,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
