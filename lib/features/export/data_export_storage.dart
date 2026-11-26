import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:personal/features/auth/google_drive_client.dart';

const dataExportFileSuffix = '.md';

/// Saves personal-data exports to the Google Drive [DriveFolders.app]
/// folder, next to the timeline and the settings backup.
class DataExportStorage {
  const DataExportStorage._();

  static const DataExportStorage instance = DataExportStorage._();

  static String fileNameFor(DateTime generatedAt) =>
      '${DriveFiles.dataExportPrefix}'
      '${DateFormat('yyyyMMdd-HHmmss').format(generatedAt)}'
      '$dataExportFileSuffix';

  /// Uploads [markdown] and returns where it went, for the confirmation.
  Future<String> save(String markdown, {required DateTime generatedAt}) async {
    final fileName = fileNameFor(generatedAt);
    await GoogleDriveClient().saveFile(
      folderName: DriveFolders.app,
      fileName: fileName,
      bytes: utf8.encode(markdown),
      mimeType: 'text/markdown',
      interactive: true,
    );
    return '${DriveFolders.app}/$fileName';
  }
}
