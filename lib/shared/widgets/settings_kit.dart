import 'package:flutter/material.dart';

import 'package:personal/core/theme/app_theme.dart';
import 'package:personal/shared/widgets/app_card.dart';

/// Building blocks every settings page shares, so they all read the same:
/// a header card saying what the page is for and how it stands, then
/// labelled groups of rows on one card each.

/// Left inset of text in a row, past its icon; also where nested rows and
/// row dividers start.
const double kSettingsRowInset = 68;

/// Tinted rounded square that leads a row or the page header.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, this.color, {super.key, this.size = 36});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Icon(icon, size: size / 2, color: color),
    );
  }
}

/// The card at the top of a settings page: what the page controls, its
/// current state as a coloured line, and the page's main actions.
class SettingsPageHeader extends StatelessWidget {
  const SettingsPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.status,
    this.statusColor,
    this.leading,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String description;

  /// Short state line, e.g. "Connected" or "2 problems". Hidden when null.
  final String? status;

  /// Colour of the status dot and text, and the card's tint. Muted when null.
  final Color? statusColor;

  /// Replaces the icon, e.g. with an account photo.
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final tint = statusColor ?? palette.textMuted;

    return AppCard(
      tier: AppCardTier.hero,
      accent: tint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading ?? SettingsIcon(icon, tint, size: 48),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    if (status != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                        liveRegion: true,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tint,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                status!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: statusColor ?? palette.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.end,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

/// A labelled group: an uppercase label, its rows on one card with hairline
/// dividers, and an optional note underneath.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.label,
    required this.children,
    this.footer,
    this.trailing,
    this.dividers = true,
  });

  final String label;
  final List<Widget> children;
  final String? footer;

  /// Shown at the end of the label line, e.g. a count.
  final Widget? trailing;

  /// Hairlines between rows. Off for children that bring their own spacing.
  final bool dividers;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              0,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label.toUpperCase(), style: context.sectionLabel),
                ),
                ?trailing,
              ],
            ),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0 && dividers)
                    Divider(
                      height: 1,
                      indent: kSettingsRowInset,
                      color: palette.border,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
                0,
              ),
              child: Text(
                footer!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// One settings row: icon, title, optional subtitle, optional trailing
/// widget. Without an icon it is a nested row, inset to line up with the
/// text of the row above.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.leading,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.enabled = true,
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;

  /// Replaces the icon square, e.g. with a spinner or a radio.
  final Widget? leading;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Shows a chevron after [trailing], for rows that open another screen.
  final bool chevron;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;
    final lead =
        leading ??
        (icon == null
            ? null
            : SettingsIcon(icon!, iconColor ?? palette.accent));

    final row = Padding(
      padding: EdgeInsets.fromLTRB(
        lead == null ? kSettingsRowInset : AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          if (lead != null) ...[lead, const SizedBox(width: AppSpacing.md + 4)],
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
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: subtitleColor ?? palette.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          if (chevron) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ],
      ),
    );

    final body = Opacity(opacity: enabled ? 1 : 0.5, child: row);
    if (onTap == null) return body;
    return InkWell(onTap: enabled ? onTap : null, child: body);
  }
}

/// A row with a switch; tapping anywhere on it flips the switch.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.icon,
    this.iconColor,
    this.subtitle,
  });

  final String title;
  final bool value;

  /// Null disables the row.
  final ValueChanged<bool>? onChanged;
  final IconData? icon;

  /// Icon tint while on; muted while off.
  final Color? iconColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: SettingsTile(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: value ? (iconColor ?? palette.accent) : palette.textMuted,
        enabled: onChanged != null,
        onTap: onChanged == null ? null : () => onChanged(!value),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}

/// Small coloured label, e.g. "Active" or "Key saved".
class SettingsBadge extends StatelessWidget {
  const SettingsBadge(this.label, this.color, {super.key, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.medium),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
