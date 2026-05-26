import 'package:dir_picker/dir_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/location/timeline_edits_file_finder.dart';

void main() {
  test('findLatestTimelineEditsEntry picks newest file by lastModified', () {
    final older = DateTime.utc(2026, 5, 20);
    final newer = DateTime.utc(2026, 5, 24);

    final match = findLatestTimelineEditsEntry([
      FileSystemEntry(
        name: 'Timeline Edits.json',
        relativePath: 'Timeline Edits.json',
        isDirectory: false,
        uri: Uri.parse('content://test/older'),
        lastModified: older,
      ),
      FileSystemEntry(
        name: 'timeline edits.json',
        relativePath: 'timeline edits.json',
        isDirectory: false,
        uri: Uri.parse('content://test/newer'),
        lastModified: newer,
      ),
    ]);

    expect(match, isNotNull);
    expect(match!.fileName, 'timeline edits.json');
    expect(match.uri.toString(), 'content://test/newer');
  });

  test('findLatestTimelineEditsEntry ignores non-timeline files', () {
    expect(
      findLatestTimelineEditsEntry([
        FileSystemEntry(
          name: 'notes.txt',
          relativePath: 'notes.txt',
          isDirectory: false,
          uri: Uri.parse('content://test/notes'),
          lastModified: DateTime.utc(2026, 5, 24),
        ),
        FileSystemEntry(
          name: 'Timeline.json',
          relativePath: 'Timeline.json',
          isDirectory: false,
          uri: Uri.parse('content://test/wrong-name'),
          lastModified: DateTime.utc(2026, 5, 24),
        ),
      ]),
      isNull,
    );
  });
}
