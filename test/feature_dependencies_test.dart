import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A ratchet on feature-to-feature imports: the edges that exist today are
/// allowed, a new one fails until it is added here on purpose. Removing an
/// import that is still listed also fails, so the list only shrinks.
const allowedFeatureImports = <String, Set<String>>{
  'analysis': {
    'calendar',
    'expenses',
    'forecasts',
    'game_activity',
    'health',
    'location',
    'prompts',
    'settings',
  },
  'app_update': {},
  'auth': {},
  'bike': {'auth', 'expenses', 'forecasts', 'location', 'prompts'},
  'calendar': {
    'analysis',
    'auth',
    'expenses',
    'forecasts',
    'health',
    'location',
  },
  'dashboard': {
    'analysis',
    'bike',
    'calendar',
    'expenses',
    'forecasts',
    'game_activity',
    'health',
    'home',
    'location',
    'prompts',
    'results',
    'screen_time',
    'settings',
  },
  'expenses': {
    'analysis',
    'auth',
    'calendar',
    'forecasts',
    'location',
    'prompts',
    'results',
  },
  'export': {
    'analysis',
    'health',
    'prompts',
    'results',
    'screen_time',
    'settings',
  },
  'forecasts': {
    'auth',
    'bike',
    'calendar',
    'dashboard',
    'expenses',
    'game_activity',
    'health',
    'location',
    'prompts',
    'results',
    'screen_time',
    'settings',
    'weather',
  },
  'game_activity': {'analysis'},
  'health': {'analysis', 'results'},
  'home': {
    'analysis',
    'calendar',
    'dashboard',
    'expenses',
    'export',
    'game_activity',
    'health',
    'location',
    'prompts',
    'screen_time',
    'settings',
  },
  'location': {
    'analysis',
    'auth',
    'expenses',
    'health',
    'prompts',
    'results',
    'settings',
  },
  'onboarding': {'settings'},
  'prompts': {'auth', 'bike', 'calendar'},
  'results': {
    'analysis',
    'bike',
    'calendar',
    'expenses',
    'forecasts',
    'game_activity',
    'health',
    'location',
    'prompts',
    'screen_time',
    'settings',
  },
  'screen_time': {'analysis'},
  'settings': {
    'app_update',
    'auth',
    'calendar',
    'forecasts',
    'game_activity',
    'onboarding',
    'prompts',
    'results',
    'weather',
  },
  'weather': {'location'},
};

void main() {
  final importPattern = RegExp(r"package:personal/features/([a-z_]+)/");

  Map<String, Set<String>> actualImports() {
    final result = <String, Set<String>>{};
    for (final dir in Directory('lib/features').listSync()) {
      if (dir is! Directory) continue;
      final feature = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      final imports = result.putIfAbsent(feature, () => {});
      for (final file in dir.listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        for (final m in importPattern.allMatches(file.readAsStringSync())) {
          if (m.group(1) != feature) imports.add(m.group(1)!);
        }
      }
    }
    return result;
  }

  test('no feature imports another feature it did not already use', () {
    final added = <String>[];
    actualImports().forEach((feature, imports) {
      final allowed = allowedFeatureImports[feature] ?? const <String>{};
      for (final other in imports.difference(allowed)) {
        added.add('$feature -> $other');
      }
    });
    expect(added, isEmpty, reason: 'New cross-feature imports');
  });

  test('the allow-list has no stale entries', () {
    final actual = actualImports();
    final stale = <String>[];
    allowedFeatureImports.forEach((feature, allowed) {
      for (final other in allowed.difference(actual[feature] ?? const {})) {
        stale.add('$feature -> $other');
      }
    });
    expect(stale, isEmpty, reason: 'Remove these from allowedFeatureImports');
  });
}
