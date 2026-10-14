part of 'app_drawer.dart';

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DrawerAnalysisMonthCard extends StatelessWidget {
  const _DrawerAnalysisMonthCard({
    required this.theme,
    required this.colorScheme,
    required this.monthLabel,
    required this.onTap,
  });

  final ThemeData theme;
  final ColorScheme colorScheme;
  final String monthLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadii.cardLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              _DrawerIconBadge(
                icon: Icons.date_range_outlined,
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis month',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerNavItem extends StatelessWidget {
  const _DrawerNavItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.status,
    this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Live state line; a coloured dot marks ok / needs attention.
  final StatusLine? status;
  final Widget? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = context.palette;
    final line = status;
    final dot = switch (line?.tone) {
      StatusTone.ok => palette.accent,
      StatusTone.warning => palette.warning,
      _ => null,
    };
    final text = line?.text ?? subtitle ?? '';

    return Material(
      color: Colors.transparent,
      child: Semantics(
        button: true,
        label:
            '$title. $text'
            '${line?.tone == StatusTone.warning ? '. Needs attention' : ''}',
        excludeSemantics: true,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          visualDensity: VisualDensity.compact,
          leading: _DrawerIconBadge(icon: icon, colorScheme: colorScheme),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: line?.tone == StatusTone.warning
                      ? TextStyle(color: palette.warning)
                      : null,
                ),
              ),
            ],
          ),
          trailing:
              badge ??
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _DrawerIconBadge extends StatelessWidget {
  const _DrawerIconBadge({required this.icon, required this.colorScheme});

  final IconData icon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 22, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
