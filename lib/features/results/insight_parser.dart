class InsightSection {
  const InsightSection({
    required this.title,
    this.bullets = const [],
    this.paragraph,
  });

  final String title;
  final List<String> bullets;
  final String? paragraph;

  bool get hasBullets => bullets.isNotEmpty;
}

List<InsightSection> parseInsightOutput(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty) return const [];

  final sections = <InsightSection>[];
  var currentTitle = 'Insights';
  var currentBullets = <String>[];
  var currentParagraph = StringBuffer();

  void flush() {
    final paragraph = currentParagraph.toString().trim();
    if (currentBullets.isNotEmpty || paragraph.isNotEmpty) {
      sections.add(
        InsightSection(
          title: currentTitle,
          bullets: List.unmodifiable(currentBullets),
          paragraph: paragraph.isEmpty ? null : paragraph,
        ),
      );
    }
    currentBullets = [];
    currentParagraph = StringBuffer();
  }

  for (final rawLine in trimmed.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    if (line.startsWith('- ')) {
      currentBullets.add(line.substring(2).trim());
      continue;
    }

    final isLikelyHeader = !line.contains('. ') &&
        line.length < 80 &&
        (line.endsWith(':') ||
            _knownHeaders.any((h) => line.toLowerCase().startsWith(h)));

    if (isLikelyHeader && (currentBullets.isNotEmpty || currentParagraph.isNotEmpty)) {
      flush();
      currentTitle = line.endsWith(':') ? line.substring(0, line.length - 1) : line;
      continue;
    }

    if (isLikelyHeader && currentBullets.isEmpty && currentParagraph.isEmpty) {
      currentTitle = line.endsWith(':') ? line.substring(0, line.length - 1) : line;
      continue;
    }

    if (currentParagraph.isNotEmpty) currentParagraph.writeln();
    currentParagraph.write(line);
  }

  flush();
  return sections;
}

String insightPreview(String output, {int maxLength = 140}) {
  for (final line in output.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('- ')) {
      final text = trimmed.substring(2).trim();
      if (text.length <= maxLength) return text;
      return '${text.substring(0, maxLength)}…';
    }
  }
  final flat = output.replaceAll('\n', ' ').trim();
  if (flat.length <= maxLength) return flat;
  return '${flat.substring(0, maxLength)}…';
}

const _knownHeaders = [
  'focus',
  'highlights',
  'next actions',
  'note',
  'summary',
];
