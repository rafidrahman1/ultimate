import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:personal/core/app_log.dart';
import 'package:personal/core/storage/prefs.dart';

const _enabledKey = 'game_covers_enabled_v1';

/// Whether game names may be sent to Steam's public store search to fetch
/// cover art. Off by default: nothing leaves the device until the user opts in.
final gameCoversEnabledProvider =
    AsyncNotifierProvider<GameCoversEnabledNotifier, bool>(
      GameCoversEnabledNotifier.new,
    );

class GameCoversEnabledNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await safePrefs();
    return prefs?.getBool(_enabledKey) ?? false;
  }

  Future<void> set(bool enabled) async {
    state = AsyncData(enabled);
    final prefs = await safePrefs();
    await prefs?.setBool(_enabledKey, enabled);
  }
}

/// The cached cover image for a game, or null when covers are off, the game
/// isn't on Steam, or the lookup failed.
final gameCoverProvider = FutureProvider.family<File?, String>((
  ref,
  gameName,
) async {
  final enabled = await ref.watch(gameCoversEnabledProvider.future);
  if (!enabled) return null;
  return GameCoverService.instance.coverFor(gameName);
});

class GameCoverService {
  GameCoverService._();

  static final GameCoverService instance = GameCoverService._();

  static const _cdn = 'https://cdn.cloudflare.steamstatic.com/steam/apps';

  final Map<String, Future<File?>> _inFlight = {};
  Directory? _dir;

  Future<File?> coverFor(String gameName) {
    final key = _keyFor(gameName);
    if (key.isEmpty) return Future.value(null);
    return _inFlight.putIfAbsent(key, () => _load(gameName, key));
  }

  Future<File?> _load(String gameName, String key) async {
    try {
      final dir = await _directory();
      final image = File('${dir.path}${Platform.pathSeparator}$key.jpg');
      final miss = File('${dir.path}${Platform.pathSeparator}$key.none');
      if (await image.exists()) return image;
      if (await miss.exists()) {
        // Retry misses after a week; the game may have been added since.
        final age = DateTime.now().difference(await miss.lastModified());
        if (age < const Duration(days: 7)) return null;
      }

      final appId = await _searchSteam(gameName);
      final bytes = appId == null ? null : await _downloadCover(appId);
      if (bytes == null) {
        await miss.writeAsString('');
        return null;
      }
      final tmp = File('${image.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(image.path);
      return image;
    } catch (error) {
      // Network or disk trouble: don't remember a miss, so it retries later.
      AppLog.warn('Game cover lookup failed for "$gameName": $error');
      unawaited(_inFlight.remove(key));
      return null;
    }
  }

  Future<int?> _searchSteam(String gameName) async {
    final uri = Uri.https('store.steampowered.com', '/api/storesearch/', {
      'term': gameName,
      'l': 'english',
      'cc': 'us',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw HttpException('Steam search returned ${response.statusCode}');
    }
    final items = (jsonDecode(response.body) as Map)['items'];
    if (items is! List) return null;

    final wanted = _normalize(gameName);
    for (final item in items) {
      if (item is Map &&
          item['type'] == 'app' &&
          _normalize('${item['name']}') == wanted) {
        return (item['id'] as num?)?.toInt();
      }
    }
    return null; // Exact titles only; a wrong cover is worse than none.
  }

  Future<List<int>?> _downloadCover(int appId) async {
    // Portrait art suits the square tile; not every app has it.
    for (final file in const ['library_600x900.jpg', 'header.jpg']) {
      final response = await http
          .get(Uri.parse('$_cdn/$appId/$file'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    }
    return null;
  }

  Future<Directory> _directory() async {
    var dir = _dir;
    if (dir == null) {
      final base = await getApplicationSupportDirectory();
      dir = Directory('${base.path}${Platform.pathSeparator}game_covers');
      _dir = dir;
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _normalize(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[™®©]'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  static String _keyFor(String name) {
    final slug = _normalize(name).replaceAll(' ', '_');
    return slug.length > 80 ? slug.substring(0, 80) : slug;
  }
}
