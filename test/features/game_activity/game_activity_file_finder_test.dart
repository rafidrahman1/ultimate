import 'dart:io';

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

  test('findLatestGameActivityEntry accepts Windows duplicate names', () {
    final match = findLatestGameActivityEntry([
      FileSystemEntry(
        name: 'GameActivity_Export.csv',
        relativePath: 'GameActivity_Export.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/legacy'),
        lastModified: DateTime(2026, 5, 28),
      ),
      FileSystemEntry(
        name: 'GameActivity_Export - DESKTOP-PS7EJB5.csv',
        relativePath: 'GameActivity_Export - DESKTOP-PS7EJB5.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/newer'),
        lastModified: DateTime(2026, 6, 16),
      ),
    ]);

    expect(match, isNotNull);
    expect(match!.fileName, 'GameActivity_Export - DESKTOP-PS7EJB5.csv');
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

  test('deleteStaleGameActivityExportsOnDisk removes older exports', () async {
    final dir = await Directory.systemTemp.createTemp('game_activity_test_');
    try {
      final keep = File('${dir.path}/GameActivity_Export - DESKTOP-PS7EJB5.csv');
      final stale = File('${dir.path}/GameActivity_Export.csv');
      final other = File('${dir.path}/GameActivity_Export - DESKTOP-PS7EJB5 - DESKTOP-PS7EJB5.csv');
      await keep.writeAsString('keep');
      await stale.writeAsString('stale');
      await other.writeAsString('other');

      await deleteStaleGameActivityExportsOnDisk(
        dir.path,
        keepFileName: keep.uri.pathSegments.last,
      );

      expect(await keep.exists(), isTrue);
      expect(await stale.exists(), isFalse);
      expect(await other.exists(), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
