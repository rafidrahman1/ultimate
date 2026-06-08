/// Strips common Markdown markers (bold, italics, leading headers) to plain text.
String stripMarkdown(String text) {
  return text
      .replaceAllMapped(
        RegExp(r'\*\*([^*]+)\*\*'),
        (match) => match.group(1) ?? '',
      )
      .replaceAllMapped(
        RegExp(r'\*([^*]+)\*'),
        (match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'^#{1,6}\s*'), '')
      .trim();
}
