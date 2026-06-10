import 'dart:io';

import 'package:personal/core/data_folder_settings_service.dart';

/// Legacy alias kept for existing preferences migration and tests.
const analysisReportsFolderUriKey = appDataFolderUriKey;
const analysisReportsFolderLabelKey = appDataFolderLabelKey;

Directory? directoryFromReportsFolderUri(String uriString) {
  final uri = Uri.tryParse(uriString.trim());
  if (uri == null) return null;

  if (uri.scheme == 'file') {
    return Directory(uri.toFilePath());
  }

  if (uri.scheme == 'content' && uri.pathSegments.contains('tree')) {
    final treeId = Uri.decodeComponent(uri.pathSegments.last);
    final separatorIndex = treeId.indexOf(':');
    if (separatorIndex >= 0 && separatorIndex < treeId.length - 1) {
      final relativePath = treeId.substring(separatorIndex + 1);
      if (relativePath.isNotEmpty) {
        return Directory(
          '/storage/emulated/0${Platform.pathSeparator}'
          '${relativePath.replaceAll('/', Platform.pathSeparator)}',
        );
      }
    }
  }

  return null;
}
