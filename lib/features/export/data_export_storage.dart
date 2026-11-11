import 'dart:io';

import 'package:intl/intl.dart';
import 'package:personal/core/storage/data_folder_directory.dart';

const dataExportFilePrefix = 'personal-data-export-';
const dataExportFileSuffix = '.md';

/// Writes personal-data export files into the user-selected data folder,
/// resolved (and permission-checked) by [DataFolderDirectory].
class DataExportStorage {
  DataExportStorage._({Directory? directoryOverride})
    : _directoryOverride = directoryOverride;

  static final DataExportStorage instance = DataExportStorage._();

  factory DataExportStorage.forDirectory(Directory directory) {
    return DataExportStorage._(directoryOverride: directory);
  }

  final Directory? _directoryOverride;

  /// Resolves the configured save folder. Never creates folders automatically.
  Future<Directory> exportDirectory() async {
    final override = _directoryOverride;
    if (override != null) {
      if (!await override.exists()) {
        throw StateError('Export save folder does not exist: ${override.path}');
      }
      return override;
    }

    return DataFolderDirectory.instance.resolve();
  }

  Future<File> save(String markdown, {required DateTime generatedAt}) async {
    final dir = await exportDirectory();
    final timestamp = DateFormat('yyyyMMdd-HHmmss').format(generatedAt);
    final file = File(
      '${dir.path}${Platform.pathSeparator}'
      '$dataExportFilePrefix$timestamp$dataExportFileSuffix',
    );
    await file.writeAsString(markdown);
    return file;
  }
}
