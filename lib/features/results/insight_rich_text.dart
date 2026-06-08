import 'package:flutter/material.dart';

import 'package:personal/features/results/insight_text.dart';

class HighlightedInsightText extends StatelessWidget {
  const HighlightedInsightText({
    super.key,
    required this.text,
    required this.highlightColor,
    this.highlights = const [],
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final List<String> highlights;
  final Color highlightColor;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    final plain = stripMarkdown(text);

    if (highlights.isEmpty) {
      final spans = <InlineSpan>[];
      final pattern = RegExp(r'\*\*([^*]+)\*\*');
      var start = 0;
      for (final match in pattern.allMatches(text)) {
        if (match.start > start) {
          spans.add(TextSpan(text: text.substring(start, match.start)));
        }
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: highlightColor,
            ),
          ),
        );
        start = match.end;
      }
      if (spans.isEmpty) {
        return Text(plain, style: base, maxLines: maxLines, overflow: overflow);
      }
      if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
      return Text.rich(
        TextSpan(style: base, children: spans),
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final terms =
        highlights.map(stripMarkdown).where((t) => t.isNotEmpty).toList()
          ..sort((a, b) => b.length.compareTo(a.length));

    final spans = <InlineSpan>[];
    var index = 0;
    while (index < plain.length) {
      String? matchTerm;
      var matchStart = plain.length;
      for (final term in terms) {
        final pos = plain.indexOf(term, index);
        if (pos >= 0 && pos < matchStart) {
          matchStart = pos;
          matchTerm = term;
        }
      }
      if (matchTerm == null) {
        spans.add(TextSpan(text: plain.substring(index)));
        break;
      }
      if (matchStart > index) {
        spans.add(TextSpan(text: plain.substring(index, matchStart)));
      }
      spans.add(
        TextSpan(
          text: matchTerm,
          style: TextStyle(fontWeight: FontWeight.w700, color: highlightColor),
        ),
      );
      index = matchStart + matchTerm.length;
    }

    return Text.rich(
      TextSpan(style: base, children: spans),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
