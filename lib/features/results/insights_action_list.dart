part of 'insights_dashboard.dart';

/// Groups [directives] by domain when multiple categories are present.
class InsightsGroupedActionList extends StatelessWidget {
  const InsightsGroupedActionList({
    super.key,
    required this.directives,
    required this.weekState,
    required this.onToggle,
    this.onEditNote,
  });

  final List<ActionDirective> directives;
  final WeekChecklistState weekState;
  final ValueChanged<int> onToggle;
  final ValueChanged<int>? onEditNote;

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesFor(directives);
    if (categories.isEmpty) {
      return InsightsActionList(
        directives: directives,
        globalOffset: 0,
        weekState: weekState,
        onToggle: onToggle,
        onEditNote: onEditNote,
      );
    }

    if (categories.length == 1) {
      return InsightsActionList(
        directives: directives,
        globalOffset: 0,
        weekState: weekState,
        onToggle: onToggle,
        onEditNote: onEditNote,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < categories.length; i++) ...[
          _ActionGroupHeader(
            label:
                _groupHeaderFor(directives, categories[i]) ??
                categories[i].label,
            category: categories[i],
          ),
          const SizedBox(height: 8),
          InsightsActionList(
            directives: directives
                .where((a) => a.categoryEnum == categories[i])
                .toList(),
            globalOffset: _globalOffsetForCategory(directives, categories, i),
            weekState: weekState,
            onToggle: onToggle,
            onEditNote: onEditNote,
          ),
          if (i < categories.length - 1) const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _ActionGroupHeader extends StatelessWidget {
  const _ActionGroupHeader({required this.label, required this.category});

  final String label;
  final InsightItemCategory category;

  @override
  Widget build(BuildContext context) {
    final visual = _ActionVisual.forCategory(category, context.palette);
    return Row(
      children: [
        Icon(visual.icon, size: 18, color: visual.accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: context.palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Checklist rows for a single week's action directives.
class InsightsActionList extends StatelessWidget {
  const InsightsActionList({
    super.key,
    required this.directives,
    required this.globalOffset,
    required this.weekState,
    required this.onToggle,
    this.onEditNote,
  });

  final List<ActionDirective> directives;
  final int globalOffset;
  final WeekChecklistState weekState;
  final ValueChanged<int> onToggle;
  final ValueChanged<int>? onEditNote;

  @override
  Widget build(BuildContext context) {
    if (directives.isEmpty) {
      return Text(
        'No actions in this group.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.palette.textMuted),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < directives.length; i++)
          _ActionTile(
            directive: directives[i],
            index: globalOffset + i,
            status: weekState.statusFor(globalOffset + i),
            onToggle: () => onToggle(globalOffset + i),
            note: weekState.notes[globalOffset + i],
            onEditNote: onEditNote == null
                ? null
                : () => onEditNote!(globalOffset + i),
          ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.directive,
    required this.index,
    required this.status,
    required this.onToggle,
    this.note,
    this.onEditNote,
  });

  final ActionDirective directive;
  final int index;
  final ChecklistItemStatus status;
  final VoidCallback onToggle;
  final String? note;
  final VoidCallback? onEditNote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = _ActionVisual.forCategory(
      directive.categoryEnum,
      context.palette,
    );
    final resolved = status != ChecklistItemStatus.pending;
    final failed = status == ChecklistItemStatus.failed;

    final detailBody = directive.description.isNotEmpty
        ? '${directive.title}\n\n${directive.description}'
        : directive.title;

    final borderColor = context.palette.border;

    final indicatorColor = failed
        ? Theme.of(context).colorScheme.error
        : visual.accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        checked: status == ChecklistItemStatus.completed,
        label: '${directive.title}${failed ? ', failed' : ''}',
        onTap: onToggle,
        excludeSemantics: true,
        child: InsightLongPressCard(
          detailTitle: directive.title,
          detailBody: detailBody,
          accent: visual.accent,
          icon: visual.icon,
          child: Material(
            color: context.palette.cardElevated,
            borderRadius: BorderRadius.circular(AppRadii.cardLarge),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.cardLarge),
              onTap: onToggle,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.cardLarge),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      leading: ChecklistStatusCircle(
                        status: status,
                        color: indicatorColor,
                      ),
                      title: Text(
                        directive.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: resolved
                              ? context.palette.textMuted
                              : context.palette.textPrimary,
                          decoration: resolved
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: directive.description.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: HighlightedInsightText(
                                text: directive.description,
                                highlightColor: visual.accent,
                                maxLines: 1,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: context.palette.textSecondary,
                                  height: 1.45,
                                  decoration: resolved
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onEditNote != null)
                            IconButton(
                              tooltip: note == null ? 'Add note' : 'Edit note',
                              visualDensity: VisualDensity.compact,
                              onPressed: onEditNote,
                              icon: Icon(
                                note == null
                                    ? Icons.edit_note_rounded
                                    : Icons.sticky_note_2_rounded,
                                size: 20,
                                color: note == null
                                    ? context.palette.textMuted
                                    : visual.accent,
                              ),
                            ),
                          Icon(visual.icon, color: visual.accent, size: 22),
                        ],
                      ),
                    ),
                    if (note != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            note!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.palette.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.small),
        border: Border.all(color: context.palette.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.border.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        label.replaceAll('**', ''),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
