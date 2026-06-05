import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'results_folder_path.dart';

final resultsSettingsProvider =
    AsyncNotifierProvider<ResultsSettingsNotifier, ResultsSettings>(
  ResultsSettingsNotifier.new,
);

class ResultsSettings {
  const ResultsSettings({
    this.reportsFolderUri,
    this.reportsFolderLabel,
    this.needsReselect = false,
  });

  final String? reportsFolderUri;
  final String? reportsFolderLabel;
  final bool needsReselect;

  bool get hasFolder =>
      reportsFolderUri != null && reportsFolderUri!.trim().isNotEmpty;

  PickedLocation? get pickedLocation {
    if (!hasFolder) return null;
    return IOPickedLocation(Uri.parse(reportsFolderUri!));
  }

  String get displayLabel =>
      reportsFolderLabel ??
      reportsFolderUri ??
      'Pick the folder where analysis reports are saved.';
}

class ResultsSettingsNotifier extends AsyncNotifier<ResultsSettings> {
  static ResultsSettings _memoryFallback = const ResultsSettings();

  @override
  Future<ResultsSettings> build() async {
    final prefs = await _safePrefs();
    if (prefs == null) return _memoryFallback;

    final uri = prefs.getString(analysisReportsFolderUriKey)?.trim();
    final label = prefs.getString(analysisReportsFolderLabelKey)?.trim();
    if (uri != null && uri.isNotEmpty) {
      final loaded = ResultsSettings(
        reportsFolderUri: uri,
        reportsFolderLabel: label?.isEmpty ?? true ? null : label,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    return const ResultsSettings();
  }

  Future<void> saveFolder(PickedLocation location) async {
    final uri = location.uri;
    if (uri == null) {
      throw ArgumentError('Picked folder has no URI on this platform.');
    }

    final next = ResultsSettings(
      reportsFolderUri: uri.toString(),
      reportsFolderLabel: _labelFromUri(uri),
    );
    await _persist(next);
  }

  Future<void> clearFolder() => _persist(const ResultsSettings());

  Future<void> _persist(ResultsSettings next) async {
    _memoryFallback = next;
    final prefs = await _safePrefs();
    if (prefs != null) {
      if (next.reportsFolderUri == null) {
        await prefs.remove(analysisReportsFolderUriKey);
        await prefs.remove(analysisReportsFolderLabelKey);
      } else {
        await prefs.setString(analysisReportsFolderUriKey, next.reportsFolderUri!);
        if (next.reportsFolderLabel == null) {
          await prefs.remove(analysisReportsFolderLabelKey);
        } else {
          await prefs.setString(
            analysisReportsFolderLabelKey,
            next.reportsFolderLabel!,
          );
        }
      }
    } else {
      debugPrint(
        'SharedPreferences unavailable. Using in-memory results settings.',
      );
    }
    state = AsyncData(next);
  }

  String _labelFromUri(Uri uri) {
    if (uri.scheme == 'file') {
      return uri.toFilePath();
    }

    final encodedPath = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    if (encodedPath == null) return uri.toString();

    final decoded = Uri.decodeComponent(encodedPath);
    final colonIndex = decoded.indexOf(':');
    if (colonIndex >= 0 && colonIndex < decoded.length - 1) {
      return decoded.substring(colonIndex + 1);
    }
    return decoded;
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } on PlatformException catch (error) {
      debugPrint('SharedPreferences channel error: $error');
      return null;
    } catch (error) {
      debugPrint('SharedPreferences init failed: $error');
    }
    return null;
  }
}
