import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;

import 'package:personal/features/auth/google_account_service.dart';

const _driveScopes = googleDriveScopes;

/// A text file downloaded from Google Drive.
class DriveTextFile {
  const DriveTextFile({
    required this.content,
    required this.fileName,
    required this.accountEmail,
  });

  final String content;
  final String fileName;
  final String accountEmail;
}

/// Read-only Google Drive access for files the app imports.
class GoogleDriveClient {
  GoogleDriveClient({GoogleAccountService? accountService})
    : _accountService = accountService ?? GoogleAccountService();

  final GoogleAccountService _accountService;

  /// Downloads the newest file in any Drive folder named [folderName] whose
  /// name passes [fileNameMatches].
  ///
  /// [nameQuery] is a Drive query fragment that narrows the listing
  /// server-side (e.g. `name = 'outbox.csv'`). Files are ranked by
  /// [timestampOf] when it returns a value, otherwise by modified time.
  Future<DriveTextFile> fetchNewestFileInFolder({
    required String folderName,
    required String nameQuery,
    required bool Function(String name) fileNameMatches,
    required String fileDescription,
    DateTime? Function(String name)? timestampOf,
    bool interactiveSignIn = false,
  }) async {
    final account = await _accountService.resolveSessionAccount(
      interactive: interactiveSignIn,
    );
    if (account == null) {
      throw const FormatException(
        'Google account not connected. Open Google account settings and sign in.',
      );
    }

    var authorization = await account.authorizationClient
        .authorizationForScopes(_driveScopes);

    if (authorization == null && interactiveSignIn) {
      authorization = await account.authorizationClient.authorizeScopes(
        _driveScopes,
      );
    }

    if (authorization == null) {
      throw const FormatException(
        'Google Drive access was not granted. Connect again and allow Drive read access.',
      );
    }

    final client = authorization.authClient(scopes: _driveScopes);
    try {
      final api = gdrive.DriveApi(client);
      final file = await _findNewestFile(
        api,
        folderName: folderName,
        nameQuery: nameQuery,
        fileNameMatches: fileNameMatches,
        fileDescription: fileDescription,
        timestampOf: timestampOf,
      );
      final fileName = file.name ?? fileDescription;
      if (file.id == null || file.id!.isEmpty) {
        throw FormatException('Could not read "$fileName" from Google Drive.');
      }

      final media =
          await api.files.get(
                file.id!,
                downloadOptions: gdrive.DownloadOptions.fullMedia,
              )
              as gdrive.Media;

      final bytes = await media.stream.expand((chunk) => chunk).toList();
      final content = utf8.decode(bytes, allowMalformed: true);
      if (content.trim().isEmpty) {
        throw FormatException(
          '"$fileName" in Google Drive folder "$folderName" is empty.',
        );
      }

      return DriveTextFile(
        content: content,
        fileName: fileName,
        accountEmail: account.email,
      );
    } finally {
      client.close();
    }
  }

  Future<gdrive.File> _findNewestFile(
    gdrive.DriveApi api, {
    required String folderName,
    required String nameQuery,
    required bool Function(String name) fileNameMatches,
    required String fileDescription,
    DateTime? Function(String name)? timestampOf,
  }) async {
    final folders = await _listFolders(api, folderName);
    if (folders.isEmpty) {
      throw FormatException('No "$folderName" folder found in Google Drive.');
    }

    final candidates = <gdrive.File>[];
    for (final folder in folders) {
      final folderId = folder.id;
      if (folderId == null || folderId.isEmpty) continue;

      String? pageToken;
      do {
        final files = await api.files.list(
          q: "'$folderId' in parents and $nameQuery and trashed = false",
          spaces: 'drive',
          $fields: 'nextPageToken, files(id, name, modifiedTime)',
          pageSize: 100,
          pageToken: pageToken,
        );
        candidates.addAll(
          (files.files ?? const <gdrive.File>[]).where(
            (f) => f.name != null && fileNameMatches(f.name!),
          ),
        );
        pageToken = files.nextPageToken;
      } while (pageToken != null && pageToken.isNotEmpty);
    }

    final match = pickNewestDriveFile(candidates, timestampOf: timestampOf);
    if (match == null) {
      throw FormatException(
        'No $fileDescription found in the "$folderName" folder on Google Drive.',
      );
    }
    return match;
  }

  Future<List<gdrive.File>> _listFolders(
    gdrive.DriveApi api,
    String folderName,
  ) async {
    final escaped = folderName.replaceAll("'", r"\'");
    final response = await api.files.list(
      q: "name = '$escaped' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, modifiedTime)',
      pageSize: 20,
    );
    return response.files ?? const [];
  }
}

/// Picks the newest file when multiple matches exist, by [timestampOf] the
/// file name when it gives one, otherwise by modified time.
gdrive.File? pickNewestDriveFile(
  Iterable<gdrive.File> files, {
  DateTime? Function(String name)? timestampOf,
}) {
  final list = files.toList();
  if (list.isEmpty) return null;

  DateTime? stamp(gdrive.File f) {
    final name = f.name;
    final fromName = (name != null && timestampOf != null)
        ? timestampOf(name)
        : null;
    return fromName ?? f.modifiedTime;
  }

  gdrive.File? newest;
  DateTime? newestStamp;

  for (final file in list) {
    final s = stamp(file);
    if (newest == null) {
      newest = file;
      newestStamp = s;
      continue;
    }

    if (s != null && (newestStamp == null || s.isAfter(newestStamp))) {
      newest = file;
      newestStamp = s;
    }
  }

  return newest ?? list.first;
}
