import 'dart:convert';
import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/drive/v3.dart' as gdrive;

import 'package:personal/features/auth/google_account_service.dart';

const _driveScopes = googleDriveScopes;

/// The Google Drive folder the app keeps its files in: the timeline, the
/// settings backup and data exports.
const appDriveFolderName = 'Timeline';

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

/// A file downloaded from Google Drive as bytes.
class DriveBytesFile {
  const DriveBytesFile({
    required this.bytes,
    required this.fileName,
    required this.accountEmail,
    required this.version,
  });

  final Uint8List bytes;
  final String fileName;
  final String accountEmail;

  /// Changes whenever the file on Drive does (its id and modified time).
  final String version;
}

bool _isWhitespaceByte(int b) =>
    b == 0x20 || b == 0x09 || b == 0x0a || b == 0x0d;

/// Marks files this app saved, so it never overwrites one you put there.
const _writtenByKey = 'writtenBy';
const _writtenByValue = 'personal-app';

/// Google Drive access: reads files the app imports, and saves the few it
/// writes (with write access asked for separately).
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
    final file = (await fetchNewestBytesInFolder(
      folderName: folderName,
      nameQuery: nameQuery,
      fileNameMatches: fileNameMatches,
      fileDescription: fileDescription,
      timestampOf: timestampOf,
      interactiveSignIn: interactiveSignIn,
    ))!;
    return DriveTextFile(
      content: utf8.decode(file.bytes, allowMalformed: true),
      fileName: file.fileName,
      accountEmail: file.accountEmail,
    );
  }

  /// Like [fetchNewestFileInFolder], as raw bytes, for large files.
  ///
  /// Returns null without downloading when the newest file's
  /// [DriveBytesFile.version] is [unlessVersion], i.e. unchanged since then.
  Future<DriveBytesFile?> fetchNewestBytesInFolder({
    required String folderName,
    required String nameQuery,
    required bool Function(String name) fileNameMatches,
    required String fileDescription,
    DateTime? Function(String name)? timestampOf,
    bool interactiveSignIn = false,
    String? unlessVersion,
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
      final version =
          '${file.id}@${file.modifiedTime?.toUtc().toIso8601String() ?? ''}';
      if (unlessVersion != null && unlessVersion == version) return null;

      final media =
          await api.files.get(
                file.id!,
                downloadOptions: gdrive.DownloadOptions.fullMedia,
              )
              as gdrive.Media;

      final builder = BytesBuilder(copy: false);
      await for (final chunk in media.stream) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      if (bytes.every(_isWhitespaceByte)) {
        throw FormatException(
          '"$fileName" in Google Drive folder "$folderName" is empty.',
        );
      }

      return DriveBytesFile(
        bytes: bytes,
        fileName: fileName,
        accountEmail: account.email,
        version: version,
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

  /// Saves [content] as [fileName] in the Drive folder named [folderName]
  /// (made in My Drive if there is none), replacing the copy this app saved
  /// before. A same-named file the app didn't write is never overwritten.
  ///
  /// Returns false, without prompting, when not [interactive] and the
  /// account or write access isn't there yet.
  Future<bool> saveTextFile({
    required String folderName,
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/json',
    bool interactive = false,
  }) async {
    final account = await _accountService.resolveSessionAccount(
      interactive: interactive,
    );
    if (account == null) {
      if (!interactive) return false;
      throw const FormatException(
        'Google account not connected. Open Google account settings and sign in.',
      );
    }
    var authorization = await account.authorizationClient
        .authorizationForScopes(googleDriveWriteScopes);
    if (authorization == null && interactive) {
      authorization = await account.authorizationClient.authorizeScopes(
        googleDriveWriteScopes,
      );
    }
    if (authorization == null) {
      if (!interactive) return false;
      throw const FormatException(
        'Google Drive access was not granted. Allow Drive access to save files.',
      );
    }

    final client = authorization.authClient(scopes: googleDriveWriteScopes);
    try {
      final api = gdrive.DriveApi(client);
      final folderId = await _folderForWriting(api, folderName, fileName);
      final escaped = fileName.replaceAll("'", r"\'");
      final existing = await api.files.list(
        q: "'$folderId' in parents and name = '$escaped' and trashed = false",
        spaces: 'drive',
        $fields: 'files(id, name, appProperties)',
        pageSize: 20,
      );
      final files = existing.files ?? const <gdrive.File>[];
      final ours = files
          .where((f) => f.appProperties?[_writtenByKey] == _writtenByValue)
          .firstOrNull;
      if (ours == null && files.isNotEmpty) {
        throw FormatException(
          'A "$fileName" this app didn\'t write is already in the "$folderName" '
          'folder on Google Drive. Move or rename it so it isn\'t overwritten.',
        );
      }

      final media = gdrive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: mimeType,
      );
      // Resumable: a multi-year timeline is well over the 5 MB simple limit.
      final options = gdrive.ResumableUploadOptions();
      if (ours?.id != null) {
        await api.files.update(
          gdrive.File(),
          ours!.id!,
          uploadMedia: media,
          uploadOptions: options,
        );
      } else {
        await api.files.create(
          gdrive.File(
            name: fileName,
            parents: [folderId],
            mimeType: mimeType,
            appProperties: {_writtenByKey: _writtenByValue},
          ),
          uploadMedia: media,
          uploadOptions: options,
        );
      }
      return true;
    } finally {
      client.close();
    }
  }

  /// The folder to save into: one already holding our [fileName], else the
  /// first one named [folderName], else a new one in My Drive.
  Future<String> _folderForWriting(
    gdrive.DriveApi api,
    String folderName,
    String fileName,
  ) async {
    final folders = [
      for (final f in await _listFolders(api, folderName))
        if (f.id != null && f.id!.isNotEmpty) f.id!,
    ];
    if (folders.length > 1) {
      final escaped = fileName.replaceAll("'", r"\'");
      final mine = await api.files.list(
        q:
            "name = '$escaped' and appProperties has "
            "{ key='$_writtenByKey' and value='$_writtenByValue' } "
            'and trashed = false',
        spaces: 'drive',
        $fields: 'files(id, parents)',
        pageSize: 10,
      );
      for (final file in mine.files ?? const <gdrive.File>[]) {
        for (final parent in file.parents ?? const <String>[]) {
          if (folders.contains(parent)) return parent;
        }
      }
    }
    if (folders.isNotEmpty) return folders.first;
    final created = await api.files.create(
      gdrive.File(
        name: folderName,
        mimeType: 'application/vnd.google-apps.folder',
      ),
      $fields: 'id',
    );
    final id = created.id;
    if (id == null || id.isEmpty) {
      throw FormatException('Could not create "$folderName" on Google Drive.');
    }
    return id;
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
