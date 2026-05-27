import 'package:dir_picker/dir_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _locationFolderUriKey = 'location_timeline_folder_uri_v1';
const _locationFolderLabelKey = 'location_timeline_folder_label_v1';
const _legacyLocationFolderPathKey = 'location_timeline_folder_path_v1';

final locationSettingsProvider =
    AsyncNotifierProvider<LocationSettingsNotifier, LocationSettings>(
      LocationSettingsNotifier.new,
    );

class LocationSettings {
  const LocationSettings({
    this.timelineFolderUri,
    this.timelineFolderLabel,
    this.needsReselect = false,
  });

  final String? timelineFolderUri;
  final String? timelineFolderLabel;
  final bool needsReselect;

  bool get hasFolder =>
      timelineFolderUri != null && timelineFolderUri!.trim().isNotEmpty;

  PickedLocation? get pickedLocation {
    if (!hasFolder) return null;
    return IOPickedLocation(Uri.parse(timelineFolderUri!));
  }

  String get displayLabel =>
      timelineFolderLabel ??
      timelineFolderUri ??
      'Pick the folder that contains Timeline.json.';
}

class LocationSettingsNotifier extends AsyncNotifier<LocationSettings> {
  static LocationSettings _memoryFallback = const LocationSettings();

  @override
  Future<LocationSettings> build() async {
    final prefs = await _safePrefs();
    if (prefs == null) return _memoryFallback;

    final uri = prefs.getString(_locationFolderUriKey)?.trim();
    final label = prefs.getString(_locationFolderLabelKey)?.trim();
    if (uri != null && uri.isNotEmpty) {
      final loaded = LocationSettings(
        timelineFolderUri: uri,
        timelineFolderLabel: label?.isEmpty ?? true ? null : label,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    final legacyPath = prefs.getString(_legacyLocationFolderPathKey)?.trim();
    if (legacyPath != null && legacyPath.isNotEmpty) {
      final loaded = LocationSettings(
        timelineFolderLabel: legacyPath,
        needsReselect: true,
      );
      _memoryFallback = loaded;
      return loaded;
    }

    return const LocationSettings();
  }

  Future<void> saveFolder(PickedLocation location) async {
    final uri = location.uri;
    if (uri == null) {
      throw ArgumentError('Picked folder has no URI on this platform.');
    }

    final next = LocationSettings(
      timelineFolderUri: uri.toString(),
      timelineFolderLabel: _labelFromUri(uri),
    );
    await _persist(next);
  }

  Future<void> clearFolder() => _persist(const LocationSettings());

  Future<void> _persist(LocationSettings next) async {
    _memoryFallback = next;
    final prefs = await _safePrefs();
    if (prefs != null) {
      if (next.timelineFolderUri == null) {
        await prefs.remove(_locationFolderUriKey);
        await prefs.remove(_locationFolderLabelKey);
        await prefs.remove(_legacyLocationFolderPathKey);
      } else {
        await prefs.setString(_locationFolderUriKey, next.timelineFolderUri!);
        if (next.timelineFolderLabel == null) {
          await prefs.remove(_locationFolderLabelKey);
        } else {
          await prefs.setString(
            _locationFolderLabelKey,
            next.timelineFolderLabel!,
          );
        }
        await prefs.remove(_legacyLocationFolderPathKey);
      }
    } else {
      debugPrint(
        'SharedPreferences unavailable. Using in-memory location settings.',
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
      return null;
    }
  }
}
