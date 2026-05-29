import 'package:flutter/material.dart';

/// Fixed header (metadata + summary) with a scrollable body beneath.
class PinnedSummaryLayout extends StatelessWidget {
  const PinnedSummaryLayout({
    super.key,
    this.header,
    required this.summary,
    required this.bodyBuilder,
    this.reserveFabSpace = true,
  });

  final Widget? header;
  final Widget summary;
  final Widget Function(BuildContext context, EdgeInsets padding) bodyBuilder;
  final bool reserveFabSpace;

  /// Scroll padding for the list region below the pinned summary.
  static EdgeInsets listPadding(
    BuildContext context, {
    bool reserveFabSpace = true,
  }) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Room for extended FAB + margin above the home indicator.
    final fabClearance = reserveFabSpace ? 96.0 : 0.0;
    return EdgeInsets.fromLTRB(20, 12, 20, 16 + safeBottom + fabClearance);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = listPadding(context, reserveFabSpace: reserveFabSpace);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[
                header!,
                const SizedBox(height: 12),
              ],
              summary,
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        Expanded(
          child: bodyBuilder(context, padding),
        ),
      ],
    );
  }
}
