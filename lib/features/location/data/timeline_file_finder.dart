/// Numbered copies use a space: `Timeline (1).json`, not `Timeline(1).json`.
final timelineNumberedJsonFileNamePattern = RegExp(
  r'^timeline \(\d+\)\.json$',
  caseSensitive: false,
);

bool isTimelineExportFileName(String name) {
  final lower = name.toLowerCase();
  return lower == 'timeline.json' ||
      timelineNumberedJsonFileNamePattern.hasMatch(lower);
}
