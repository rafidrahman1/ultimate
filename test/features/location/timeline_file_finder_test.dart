import 'package:dir_picker/dir_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/timeline_file_finder.dart';

void main() {
  test('findLatestTimelineEntry accepts Timeline.json and numbered copies', () {
    final match = findLatestTimelineEntry([
      FileSystemEntry(
        name: 'Timeline.json',
        relativePath: 'Timeline.json',
        isDirectory: false,
        uri: Uri.parse('content://test/base'),
        lastModified: DateTime.utc(2026, 5, 1),
      ),
      FileSystemEntry(
        name: 'Timeline (1).json',
        relativePath: 'Timeline (1).json',
        isDirectory: false,
        uri: Uri.parse('content://test/copy-1'),
        lastModified: DateTime.utc(2026, 5, 2, 12),
      ),
      FileSystemEntry(
        name: 'Timeline (12).json',
        relativePath: 'Timeline (12).json',
        isDirectory: false,
        uri: Uri.parse('content://test/copy-12'),
        lastModified: DateTime.utc(2026, 5, 3),
      ),
    ]);

    expect(match, isNotNull);
    expect(match!.fileName, 'Timeline (12).json');
    expect(match.uri.toString(), 'content://test/copy-12');
  });

  test('findLatestTimelineEntry ignores unrelated JSON files', () {
    expect(
      findLatestTimelineEntry([
        FileSystemEntry(
          name: 'notes.json',
          relativePath: 'notes.json',
          isDirectory: false,
          uri: Uri.parse('content://test/notes'),
        ),
        FileSystemEntry(
          name: 'Timeline(1).json',
          relativePath: 'Timeline(1).json',
          isDirectory: false,
          uri: Uri.parse('content://test/no-space'),
        ),
        FileSystemEntry(
          name: 'Timeline-backup.json',
          relativePath: 'Timeline-backup.json',
          isDirectory: false,
          uri: Uri.parse('content://test/backup'),
        ),
      ]),
      isNull,
    );
  });
}
