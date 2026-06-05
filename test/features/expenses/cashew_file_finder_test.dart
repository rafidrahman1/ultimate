import 'package:dir_picker/dir_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:Personal/features/expenses/cashew_file_finder.dart';

void main() {
  test('findLatestCashewEntry picks newest export by filename timestamp', () {
    final match = findLatestCashewEntry([
      FileSystemEntry(
        name: 'cashew-2026-05-22-16-29-44-322799.csv',
        relativePath: 'cashew-2026-05-22-16-29-44-322799.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/older'),
      ),
      FileSystemEntry(
        name: 'cashew-2026-05-24-14-27-46-480926.csv',
        relativePath: 'cashew-2026-05-24-14-27-46-480926.csv',
        isDirectory: false,
        uri: Uri.parse('content://test/newer'),
      ),
    ]);

    expect(match, isNotNull);
    expect(match!.fileName, 'cashew-2026-05-24-14-27-46-480926.csv');
    expect(match.uri.toString(), 'content://test/newer');
  });

  test('findLatestCashewEntry ignores non-cashew files', () {
    expect(
      findLatestCashewEntry([
        FileSystemEntry(
          name: 'notes.txt',
          relativePath: 'notes.txt',
          isDirectory: false,
          uri: Uri.parse('content://test/notes'),
        ),
        FileSystemEntry(
          name: 'cashew-export.csv',
          relativePath: 'cashew-export.csv',
          isDirectory: false,
          uri: Uri.parse('content://test/bad-name'),
        ),
      ]),
      isNull,
    );
  });
}
