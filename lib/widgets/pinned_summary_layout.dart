import 'package:flutter/material.dart';

/// Fixed header (metadata + summary) with a scrollable body beneath.
class PinnedSummaryLayout extends StatelessWidget {
  const PinnedSummaryLayout({
    super.key,
    this.header,
    required this.summary,
    required this.body,
    this.bodyPadding = const EdgeInsets.fromLTRB(20, 12, 20, 88),
  });

  final Widget? header;
  final Widget summary;
  final Widget body;
  final EdgeInsets bodyPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          child: Padding(
            padding: bodyPadding,
            child: body,
          ),
        ),
      ],
    );
  }
}
