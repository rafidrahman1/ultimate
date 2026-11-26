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

/// Avatar and name, on one line.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({required this.userTitle, required this.photoUrl});

  final String userTitle;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final photo = photoUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: palette.accent.withValues(
              alpha: AppOpacity.medium,
            ),
            foregroundImage: photo != null
                ? ResizeImage(NetworkImage(photo), width: 120)
                : null,
            onForegroundImageError: photo != null ? (_, _) {} : null,
            child: Icon(Icons.person, color: palette.accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              userTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
