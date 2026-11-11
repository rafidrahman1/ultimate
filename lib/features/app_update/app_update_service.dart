import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// GitHub repo whose Releases act as the update channel. Each release is
/// tagged like `v2.3.0+4` (matching `version:` in pubspec.yaml) and has the
/// release APK attached.
const updateRepo = 'rafidrahman1/ultimate';

/// A parsed `major.minor.patch+build` version.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts, this.build);

  final List<int> parts;
  final int build;

  /// Accepts `v2.3.0+4`, `2.3.0+4` or `2.3.0`. Returns null when unparseable.
  static AppVersion? tryParse(String raw) {
    final match = RegExp(
      r'^v?(\d+(?:\.\d+)*)(?:\+(\d+))?$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final parts = match.group(1)!.split('.').map(int.parse).toList();
    return AppVersion(parts, int.tryParse(match.group(2) ?? '') ?? 0);
  }

  @override
  int compareTo(AppVersion other) {
    final length = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < length; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return build.compareTo(other.build);
  }

  @override
  String toString() => '${parts.join('.')}+$build';
}

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.apkUrl,
    required this.notes,
    required this.sizeBytes,
  });

  final AppVersion version;
  final Uri apkUrl;
  final String notes;
  final int sizeBytes;
}

/// Reads the latest GitHub release JSON; returns an update only when it is
/// newer than [current] and has an APK asset.
AppUpdate? parseLatestRelease(Map<String, dynamic> json, AppVersion current) {
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final version = AppVersion.tryParse('${json['tag_name'] ?? ''}');
  if (version == null || version.compareTo(current) <= 0) return null;
  final assets = (json['assets'] as List?) ?? const [];
  for (final asset in assets.whereType<Map<String, dynamic>>()) {
    final name = '${asset['name']}';
    final url = asset['browser_download_url'];
    if (name.endsWith('.apk') && url is String) {
      return AppUpdate(
        version: version,
        apkUrl: Uri.parse(url),
        notes: '${json['body'] ?? ''}'.trim(),
        sizeBytes: (asset['size'] as num?)?.toInt() ?? 0,
      );
    }
  }
  return null;
}

class AppUpdateService {
  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Null when up to date. Throws on network errors.
  Future<AppUpdate?> checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final current = AppVersion.tryParse('${info.version}+${info.buildNumber}');
    if (current == null) return null;
    final response = await _client
        .get(
          Uri.https('api.github.com', '/repos/$updateRepo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 404) return null; // no releases yet
    if (response.statusCode != 200) {
      throw HttpException('Update check failed (${response.statusCode})');
    }
    return parseLatestRelease(
      jsonDecode(response.body) as Map<String, dynamic>,
      current,
    );
  }

  /// Downloads the APK (reporting 0..1 progress) then hands it to the
  /// system installer. A stalled or truncated download throws instead of
  /// reaching the installer.
  Future<void> downloadAndInstall(
    AppUpdate update, {
    void Function(double progress)? onProgress,
    Duration stallTimeout = const Duration(seconds: 30),
  }) async {
    final dir = await getTemporaryDirectory();
    await deleteDownloadedApks(dir);
    final file = File(p.join(dir.path, 'personal-${update.version}.apk'));
    await downloadApk(
      update,
      file,
      onProgress: onProgress,
      stallTimeout: stallTimeout,
    );
    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw FileSystemException(result.message, file.path);
    }
  }

  /// Streams the APK into [file]. Throws (and removes the partial file) when
  /// the server errors, the connection stalls for [stallTimeout], or the
  /// byte count differs from the size the release advertised.
  @visibleForTesting
  Future<void> downloadApk(
    AppUpdate update,
    File file, {
    void Function(double progress)? onProgress,
    Duration stallTimeout = const Duration(seconds: 30),
  }) async {
    try {
      final response = await _client
          .send(http.Request('GET', update.apkUrl))
          .timeout(stallTimeout);
      if (response.statusCode != 200) {
        throw HttpException('Download failed (${response.statusCode})');
      }
      final total = response.contentLength ?? update.sizeBytes;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in response.stream.timeout(stallTimeout)) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
      } finally {
        await sink.close();
      }
      if (update.sizeBytes > 0 && received != update.sizeBytes) {
        throw HttpException(
          'Download incomplete ($received of ${update.sizeBytes} bytes)',
        );
      }
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }
}

/// Removes APKs left in [dir] by earlier updates.
Future<void> deleteDownloadedApks(Directory dir) async {
  if (!await dir.exists()) return;
  await for (final entry in dir.list()) {
    final name = p.basename(entry.path);
    if (entry is File &&
        name.startsWith('personal-') &&
        name.endsWith('.apk')) {
      try {
        await entry.delete();
      } on FileSystemException {
        // Still held by the installer; the next update removes it.
      }
    }
  }
}
