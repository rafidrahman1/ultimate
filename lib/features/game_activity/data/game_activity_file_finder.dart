import 'package:personal/core/app_log.dart';

/// Google Drive folder the GameActivity exports are uploaded to.
const gameActivityDriveFolderName = 'Timeline';

const gameActivityExportPrefix = 'GameActivity_Export';

bool isGameActivityExportFileName(String name) =>
    name.startsWith(gameActivityExportPrefix);

/// The export time encoded in a `GameActivity_Export_YYYY-MM-DD_HH-MM-SS`
/// file name, or null when the name doesn't carry one.
DateTime? gameActivityTimestampFromFileName(String fileName) {
  final match = RegExp(
    r'GameActivity_Export_(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})-(\d{2})',
  ).firstMatch(fileName);
  if (match == null) return null;

  try {
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  } catch (error) {
    AppLog.warn('Failed to parse timestamp from file name "$fileName": $error');
    return null;
  }
}
