part of 'app_drawer.dart';

/// One plain menu row: a coloured icon, a label and an optional trailing
/// widget.
class _DrawerRow extends StatelessWidget {
  const _DrawerRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.trailing,
    this.semanticsLabel,
  });

  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel ?? title,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: AppSpacing.lg,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: context.palette.border,
    );
  }
}

/// Small warning pill with how many settings need attention.
class _AttentionDot extends StatelessWidget {
  const _AttentionDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
