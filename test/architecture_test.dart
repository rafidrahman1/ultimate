import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the layering described in CLAUDE.md: `core/` is infrastructure and
/// must not depend on feature code, and `shared/` must not depend on features.
void main() {
  final importPattern = RegExp(r"import 'package:personal/([a-z_]+)/");

  Iterable<String> offenders(String dir, Set<String> forbidden) sync* {
    for (final file in Directory(dir).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      for (final m in importPattern.allMatches(file.readAsStringSync())) {
        if (forbidden.contains(m.group(1))) {
          yield '${file.path} imports ${m.group(0)}';
        }
      }
    }
  }

  test('core/ does not import features, shell or app', () {
    expect(offenders('lib/core', {'features', 'shell', 'app'}), isEmpty);
  });

  test('shared/ does not import features or shell', () {
    expect(offenders('lib/shared', {'features', 'shell'}), isEmpty);
  });
}
