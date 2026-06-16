import 'package:dir_picker/dir_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/game_activity/game_activity_file_finder.dart';

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

  test('findLatestGameActivityEntry accepts any suffix after GameActivity_Export', () {
    final match = findLatestGameActivityEntry([
      FileSystemEntry(
        name: 'GameActivity_Export.csv',
        relativePath: 'GameActivity_Export.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/legacy'),
        lastModified: DateTime(2026, 5, 28),
      ),
      FileSystemEntry(
        name: 'GameActivity_Export_backup.csv',
        relativePath: 'GameActivity_Export_backup.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/newer'),
        lastModified: DateTime(2026, 5, 30),
      ),
    ]);

    expect(match, isNotNull);
    expect(match!.fileName, 'GameActivity_Export_backup.csv');
  });

  test('findLatestGameActivityEntry ignores unrelated files', () {
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
