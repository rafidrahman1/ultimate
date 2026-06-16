/// Parses and splices weekly checklist blocks from monthly insights markdown.
class ChecklistWeekMarkdownSection {
  const ChecklistWeekMarkdownSection({
    required this.weekNumber,
    required this.headerLine,
    required this.markdown,
    required this.startIndex,
    required this.endIndex,
  });

  final int weekNumber;
  final String headerLine;
  final String markdown;
  final int startIndex;
  final int endIndex;
}

List<ChecklistWeekMarkdownSection> parseChecklistWeekSections(String markdown) {
  final actionsStart = _findClearNextActionsIndex(markdown);
  if (actionsStart == null) return const [];

  final tail = markdown.substring(actionsStart);
  final weekHeaderPattern = RegExp(r'^#####\s+.+$', multiLine: true);
  final matches = weekHeaderPattern.allMatches(tail).toList();
  if (matches.isEmpty) return const [];

  final sections = <ChecklistWeekMarkdownSection>[];
  for (var i = 0; i < matches.length; i++) {
    final headerMatch = matches[i];
    final start = actionsStart + headerMatch.start;
    final end = i + 1 < matches.length
        ? actionsStart + matches[i + 1].start
        : markdown.length;
    final block = markdown.substring(start, end).trimRight();
    final headerLine = headerMatch.group(0)!;
    final weekNumber = weekNumberFromChecklistHeader(headerLine);
    if (weekNumber == null) continue;
    sections.add(
      ChecklistWeekMarkdownSection(
        weekNumber: weekNumber,
        headerLine: headerLine,
        markdown: block,
        startIndex: start,
        endIndex: end,
      ),
    );
  }
  return sections;
}

String replaceChecklistWeekSection(
  String markdown,
  int weekNumber,
  String newWeekMarkdown,
) {
  final sections = parseChecklistWeekSections(markdown);
  final section = checklistWeekSectionForNumber(sections, weekNumber);
  if (section == null) return markdown;

  final trimmedNew = stripGeneratedMarkdownFences(newWeekMarkdown).trim();
  final replacement = trimmedNew.endsWith('\n') ? trimmedNew : '$trimmedNew\n';
  return markdown.replaceRange(section.startIndex, section.endIndex, replacement);
}

String? extractCalendarScheduleBlock(String weekMarkdown) {
  final lines = weekMarkdown.split('\n');
  var startLine = -1;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim().toLowerCase();
    if (!lines[i].trim().startsWith('####')) continue;
    if (line.contains('calendar') && line.contains('schedule')) {
      startLine = i + 1;
      break;
    }
  }
  if (startLine == -1) return null;

  final buffer = StringBuffer();
  for (var i = startLine; i < lines.length; i++) {
    if (lines[i].trim().startsWith('####')) break;
    buffer.writeln(lines[i]);
  }
  final text = buffer.toString().trim();
  return text.isEmpty ? null : text;
}

bool calendarSectionMentionsEvent(String calendarSection, String eventTitle) {
  final normalizedTitle = normalizeEventTitleForMatch(eventTitle);
  if (normalizedTitle.isEmpty) return false;
  return normalizeEventTitleForMatch(calendarSection).contains(normalizedTitle);
}

String normalizeEventTitleForMatch(String value) {
  return value
      .replaceAll('**', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String stripGeneratedMarkdownFences(String text) {
  var trimmed = text.trim();
  if (!trimmed.startsWith('```')) return trimmed;
  trimmed = trimmed.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
  trimmed = trimmed.replaceFirst(RegExp(r'\n?```$'), '');
  return trimmed.trim();
}

int? weekNumberFromChecklistHeader(String headerLine) {
  final match = RegExp(
    r'week\s*(\d+)',
    caseSensitive: false,
  ).firstMatch(headerLine.replaceAll('**', ''));
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

int? _findClearNextActionsIndex(String markdown) {
  final match = RegExp(
    r'^#{1,3}\s*\*?\*?\s*Clear Next Actions\b',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(markdown);
  return match?.start;
}

ChecklistWeekMarkdownSection? checklistWeekSectionForNumber(
  List<ChecklistWeekMarkdownSection> sections,
  int weekNumber,
) {
  for (final section in sections) {
    if (section.weekNumber == weekNumber) return section;
  }
  return null;
}
