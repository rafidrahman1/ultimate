import 'package:flutter/material.dart';

import 'package:motohealth/core/theme/app_theme.dart';

/// Renders the small markdown subset the AI is asked to use: `## ` headings,
/// `- ` bullets, and `**bold**`.
class ReportText extends StatelessWidget {
  const ReportText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) continue;
      if (line.startsWith('#')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: 4),
            child: Text(
              line.replaceFirst(RegExp(r'^#+\s*'), ''),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
      } else if (RegExp(r'^\s*([-*•]|\d+\.)\s+').hasMatch(line)) {
        final body = line.replaceFirst(RegExp(r'^\s*([-*•]|\d+\.)\s+'), '');
        final indent = line.length - line.trimLeft().length;
        children.add(
          Padding(
            padding: EdgeInsets.only(left: indent > 1 ? 16 : 0, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1, right: 8),
                  child: Text('•'),
                ),
                Expanded(child: _rich(context, body)),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _rich(context, line),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _rich(BuildContext context, String line) {
    final base = Theme.of(context).textTheme.bodyMedium!.copyWith(height: 1.4);
    final spans = <TextSpan>[];
    final parts = line.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(
        TextSpan(
          text: parts[i],
          style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w800) : null,
        ),
      );
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
