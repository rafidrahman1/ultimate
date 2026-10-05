import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/theme/theme_mode_controller.dart';
import 'package:personal/features/calendar/calendar_settings_screen.dart';
import 'package:personal/features/onboarding/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('signInHelp', () {
    test('explains a rejected build (missing fingerprint)', () {
      final help = signInHelp(Exception('ApiException: 10 DEVELOPER_ERROR'));
      expect(help.title, contains('rejected'));
      expect(help.steps.join(' '), contains('SHA-1'));
    });

    test('treats a cancelled sign-in as harmless', () {
      expect(signInHelp('Sign in cancelled by user').title, contains('cancel'));
    });

    test('points at the connection for network failures', () {
      expect(
        signInHelp(Exception('SocketException: network unreachable')).title,
        contains('reach'),
      );
    });

    test('falls back to generic advice', () {
      expect(signInHelp(Exception('boom')).title, 'Sign-in failed');
    });
  });

  group('onboarding flag', () {
    test('is unseen until marked, then stays seen', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await onboardingSeen(), isFalse);
      await markOnboardingSeen();
      expect(await onboardingSeen(), isTrue);
    });
  });

  group('theme mode', () {
    test('remembers the choice across launches', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      addTearDown(first.dispose);
      first.read(themeModeProvider.notifier).setDarkMode(false);
      expect(first.read(themeModeProvider), ThemeMode.light);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final second = ProviderContainer();
      addTearDown(second.dispose);
      second.read(themeModeProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(second.read(themeModeProvider), ThemeMode.light);

      second.read(themeModeProvider.notifier).setDarkMode(true);
    });
  });
}
