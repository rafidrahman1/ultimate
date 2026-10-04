import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal/core/theme/app_theme.dart';

double _luminance(Color c) => c.computeLuminance();

/// WCAG contrast ratio of [fg] over an opaque [bg].
double contrast(Color fg, Color bg) {
  final a = _luminance(Color.alphaBlend(fg, bg));
  final b = _luminance(bg);
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final entry in {
    'dark': AppTheme.darkTheme,
    'light': AppTheme.lightTheme,
  }.entries) {
    testWidgets('${entry.key} theme text and accents are readable', (
      tester,
    ) async {
      late AppPalette palette;
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Builder(
            builder: (context) {
              palette = context.palette;
              return const SizedBox();
            },
          ),
        ),
      );

      final failures = <String>[];
      void check(String what, Color fg, Color bg, double min) {
        final ratio = contrast(fg, bg);
        if (ratio < min) {
          failures.add('$what: ${ratio.toStringAsFixed(2)} (needs $min)');
        }
      }

      final surfaces = {
        'card': palette.card,
        'canvas': palette.canvas,
        'cardElevated': palette.cardElevated,
      };
      for (final surface in surfaces.entries) {
        final name = surface.key;
        final bg = surface.value;
        check('primary text on $name', palette.textPrimary, bg, 7);
        check('secondary text on $name', palette.textSecondary, bg, 4.5);
        // Muted text carries captions and hints; AA for small text.
        check('muted text on $name', palette.textMuted, bg, 4.5);
        // Accent and warning are used for icons, values and large text.
        check('accent on $name', palette.accent, bg, 3);
        check('warning on $name', palette.warning, bg, 3);
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
