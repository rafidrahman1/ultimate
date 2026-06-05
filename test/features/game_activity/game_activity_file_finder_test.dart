import 'package:dir_picker/dir_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/features/game_activity/game_activity_file_finder.dart';

void main() {
  test('findLatestGameActivityEntry picks newest export by filename timestamp', () {
    final match = findLatestGameActivityEntry([
      FileSystemEntry(
        name: 'GameActivity_Export_2026-05-29_18-12-14.csv',
        relativePath: 'GameActivity_Export_2026-05-29_18-12-14.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/older'),
      ),
      FileSystemEntry(
        name: 'GameActivity_Export_2026-05-30_11-06-23.csv',
        relativePath: 'GameActivity_Export_2026-05-30_11-06-23.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/newer'),
      ),
    ]);

    expect(match, isNotNull);
    expect(match!.fileName, 'GameActivity_Export_2026-05-30_11-06-23.csv');
    expect(match.uri.toString(), 'content://test/newer');
  });

  test('findLatestGameActivityEntry ignores non-export files', () {
    expect(
      findLatestGameActivityEntry([
        FileSystemEntry(
          name: 'notes.txt',
          relativePath: 'notes.txt',
          isDirectory: false,
          uri: Uri.parse('content://test/notes'),
        ),
        FileSystemEntry(
          name: 'game-activity.csv',
          relativePath: 'game-activity.csv',
          isDirectory: false,
          uri: Uri.parse('content://test/bad-name'),
        ),
      ]),
      isNull,
    );
  });
}
