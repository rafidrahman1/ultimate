import 'package:dir_picker/dir_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/game_activity/game_activity_file_finder.dart';

void main() {
  test('findGameActivityEntry returns GameActivity_Export.csv', () {
    final match = findGameActivityEntry([
      FileSystemEntry(
        name: 'notes.txt',
        relativePath: 'notes.txt',
        isDirectory: false,
        uri: Uri.parse('content://test/notes'),
      ),
      FileSystemEntry(
        name: 'GameActivity_Export.csv',
        relativePath: 'GameActivity_Export.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/export'),
      ),
    ]);

    expect(match, isNotNull);
    expect(match!.fileName, 'GameActivity_Export.csv');
    expect(match.uri.toString(), 'content://test/export');
  });

  test('findGameActivityEntry returns null when export is missing', () {
    expect(
      findGameActivityEntry([
        FileSystemEntry(
          name: 'notes.txt',
          relativePath: 'notes.txt',
          isDirectory: false,
          uri: Uri.parse('content://test/notes'),
        ),
        FileSystemEntry(
          name: 'GameActivity_Export_2026-05-30_11-06-23.csv',
          relativePath: 'GameActivity_Export_2026-05-30_11-06-23.csv',
          isDirectory: false,
          uri: Uri.parse('content://test/old-name'),
        ),
      ]),
      isNull,
    );
  });
}
