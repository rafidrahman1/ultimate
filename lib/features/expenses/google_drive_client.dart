import 'dart:convert';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;

import 'package:personal/features/auth/google_account_service.dart';

const cashewDriveFolderName = 'Cashew';
const cashewOutboxCsvFileName = 'outbox.csv';

const _driveScopes = googleDriveScopes;

class CashewDriveCsvResult {
  const CashewDriveCsvResult({
    required this.content,
    required this.fileName,
    required this.accountEmail,
  });

  final String content;
  final String fileName;
  final String accountEmail;
}

class GoogleDriveClient {
  GoogleDriveClient({GoogleAccountService? accountService})
    : _accountService = accountService ?? GoogleAccountService();

  final GoogleAccountService _accountService;

  Future<CashewDriveCsvResult> fetchCashewOutboxCsv({
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

    var authorization = await account.authorizationClient.authorizationForScopes(
      _driveScopes,
    );

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
      final file = await _findOutboxCsv(api);
      if (file.id == null || file.id!.isEmpty) {
        throw FormatException(
          'Could not read "$cashewOutboxCsvFileName" from Google Drive.',
        );
      }

      final media = await api.files.get(
        file.id!,
        downloadOptions: gdrive.DownloadOptions.fullMedia,
      ) as gdrive.Media;

      final bytes = await media.stream.expand((chunk) => chunk).toList();
      final content = utf8.decode(bytes);
      if (content.trim().isEmpty) {
        throw FormatException(
          '"$cashewOutboxCsvFileName" in Google Drive folder "$cashewDriveFolderName" is empty.',
        );
      }

      return CashewDriveCsvResult(
        content: content,
        fileName: cashewOutboxCsvFileName,
        accountEmail: account.email,
      );
    } finally {
      client.close();
    }
  }

  Future<gdrive.File> _findOutboxCsv(gdrive.DriveApi api) async {
    final folders = await _listCashewFolders(api);
    if (folders.isEmpty) {
      throw FormatException(
        'No "$cashewDriveFolderName" folder found in Google Drive.',
      );
    }

    for (final folder in folders) {
      final folderId = folder.id;
      if (folderId == null || folderId.isEmpty) continue;

      final files = await api.files.list(
        q:
            "'$folderId' in parents and name = '$cashewOutboxCsvFileName' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, modifiedTime)',
        pageSize: 5,
      );

      final match = pickNewestDriveFile(files.files ?? const []);
      if (match != null) return match;
    }

    throw FormatException(
      'No "$cashewOutboxCsvFileName" found in the "$cashewDriveFolderName" folder on Google Drive.',
    );
  }

  Future<List<gdrive.File>> _listCashewFolders(gdrive.DriveApi api) async {
    final response = await api.files.list(
      q:
          "name = '$cashewDriveFolderName' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name, modifiedTime)',
      pageSize: 20,
    );
    return response.files ?? const [];
  }
}

/// Picks the newest file when multiple matches exist.
gdrive.File? pickNewestDriveFile(Iterable<gdrive.File> files) {
  final list = files.toList();
  if (list.isEmpty) return null;

  gdrive.File? newest;
  DateTime? newestModified;

  for (final file in list) {
    final modified = file.modifiedTime;
    if (newest == null) {
      newest = file;
      newestModified = modified;
      continue;
    }

    if (modified != null &&
        (newestModified == null || modified.isAfter(newestModified))) {
      newest = file;
      newestModified = modified;
    }
  }

  return newest ?? list.first;
}
