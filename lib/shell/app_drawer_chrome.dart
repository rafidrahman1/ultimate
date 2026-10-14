part of 'app_drawer.dart';

class _DrawerFooter extends ConsumerWidget {
  const _DrawerFooter({required this.theme, required this.colorScheme});

  final ThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);
    final versionLabel = packageInfo.maybeWhen(
      data: (info) => info.version,
      orElse: () => null,
    );
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            height: 1,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppInfo.displayName,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (versionLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Version $versionLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(
                  isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrawerProfileHeader extends StatelessWidget {
  const _DrawerProfileHeader({
    required this.theme,
    required this.colorScheme,
    required this.isDark,
    required this.userTitle,
    required this.profilePhotoUrl,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final bool isDark;
  final String userTitle;
  final String? profilePhotoUrl;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.16),
                  backgroundImage: profilePhotoUrl != null
                      ? NetworkImage(profilePhotoUrl!)
                      : null,
                  onBackgroundImageError: profilePhotoUrl != null
                      ? (_, _) {}
                      : null,
                  child: profilePhotoUrl == null
                      ? Icon(Icons.person, color: colorScheme.primary, size: 32)
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    userTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.35 : 0.45,
            ),
            height: 1,
          ),
        ],
      ),
    );
  }
}
