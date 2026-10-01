part of 'progress_review_dashboard.dart';

// Discrepancy matrix: per-target expected vs actual table (wide) or cards (narrow).

class _DiscrepancyMatrix extends StatelessWidget {
  const _DiscrepancyMatrix({required this.rows});

  final List<DiscrepancyRow> rows;

  static const _narrowBreakpoint = 360.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return constraints.maxWidth < _narrowBreakpoint
            ? _NarrowMatrix(rows: rows)
            : _WideMatrix(rows: rows);
      },
    );
  }
}

class _WideMatrix extends StatelessWidget {
  const _WideMatrix({required this.rows});

  final List<DiscrepancyRow> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.cardLarge),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          const _MatrixHeaderRow(),
          for (var i = 0; i < rows.length; i++)
            _MatrixDataRow(row: rows[i], isLast: i == rows.length - 1),
        ],
      ),
    );
  }
}

class _NarrowMatrix extends StatelessWidget {
  const _NarrowMatrix({required this.rows});

  final List<DiscrepancyRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _MatrixRowCard(row: rows[i]),
        ],
      ],
    );
  }
}

class _MatrixRowCard extends StatelessWidget {
  const _MatrixRowCard({required this.row});

  final DiscrepancyRow row;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final tone = reviewStatusColor(context, reviewStatusFromTone(row.tone));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.domain,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: AppOpacity.subtle),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_toneIcon(row.tone), size: 13, color: tone),
                    const SizedBox(width: 4),
                    Text(
                      row.variance,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tone,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _LabeledValue(label: 'Benchmark', value: row.benchmark),
          const SizedBox(height: 4),
          _LabeledValue(label: 'Actual', value: row.actual),
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(
              color: palette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixHeaderRow extends StatelessWidget {
  const _MatrixHeaderRow();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.cardElevated,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.cardLarge - 1),
        ),
      ),
      child: Row(
        children: const [
          Expanded(flex: 24, child: _HeaderCell('Domain')),
          Expanded(flex: 28, child: _HeaderCell('Benchmark')),
          Expanded(flex: 24, child: _HeaderCell('Actual')),
          Expanded(flex: 24, child: _HeaderCell('Variance')),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.palette.textMuted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _MatrixDataRow extends StatelessWidget {
  const _MatrixDataRow({required this.row, required this.isLast});

  final DiscrepancyRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final theme = Theme.of(context);
    final tone = reviewStatusColor(context, reviewStatusFromTone(row.tone));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 24,
            child: Text(
              row.domain,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 28,
            child: Text(
              row.benchmark,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textMuted,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Text(
              row.actual,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Row(
              children: [
                Icon(_toneIcon(row.tone), size: 13, color: tone),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    row.variance,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------
