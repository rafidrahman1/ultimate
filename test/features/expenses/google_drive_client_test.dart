import 'package:googleapis/drive/v3.dart' as gdrive;
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/features/expenses/google_drive_client.dart';

void main() {
  group('pickNewestDriveFile', () {
    test('returns null for empty input', () {
      expect(pickNewestDriveFile(const []), isNull);
    });

    test('returns the only file when there is one match', () {
      final file = gdrive.File()..id = 'a';
      expect(pickNewestDriveFile([file]), same(file));
    });

    test('picks the file with the latest modifiedTime', () {
      final older = gdrive.File()
        ..id = 'old'
        ..modifiedTime = DateTime.utc(2026, 6, 14, 10);
      final newer = gdrive.File()
        ..id = 'new'
        ..modifiedTime = DateTime.utc(2026, 6, 16, 10);

      expect(pickNewestDriveFile([older, newer])?.id, 'new');
    });
  });
}
