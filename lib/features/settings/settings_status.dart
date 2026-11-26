import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/data/calendar_settings_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';
import 'package:personal/features/settings/backup_service.dart';

/// How healthy a settings area is, for the hub rows and drawer badges.
enum StatusTone { ok, warning, neutral }

/// One-line summary of an area, e.g. "me@gmail.com · backed up 3 Nov".
class StatusLine {
  const StatusLine(this.text, this.tone);

  final String text;
  final StatusTone tone;
}

/// Last backup on Google Drive, if any. Refresh with `ref.invalidate`.
final backupInfoProvider = FutureProvider.autoDispose<BackupInfo?>(
  (ref) => const BackupService().peek(),
);

/// Status of each settings area, derived from the live providers.
class SettingsStatus {
  const SettingsStatus({
    required this.ai,
    required this.profile,
    required this.account,
    required this.profileMissingCount,
  });

  final StatusLine ai;
  final StatusLine profile;
  final StatusLine account;
  final int profileMissingCount;

  /// Areas that need the user's attention.
  int get warningCount =>
      [ai, profile, account].where((s) => s.tone == StatusTone.warning).length;
}

final settingsStatusProvider = Provider<SettingsStatus>((ref) {
  final backup = ref.watch(backupInfoProvider);
  final ai = ref.watch(aiSettingsProvider).value;
  final config = ref.watch(promptConfigProvider).value;
  final calendar = ref.watch(calendarSettingsProvider).value;
  final user = ref.watch(authStateProvider).value;

  final StatusLine aiLine;
  if (ai == null) {
    aiLine = const StatusLine('Loading…', StatusTone.neutral);
  } else if (!ai.enableApiCalls) {
    aiLine = const StatusLine('On-device only', StatusTone.neutral);
  } else {
    final key = switch (ai.provider) {
      AiProvider.openai => ai.openAiApiKey,
      AiProvider.gemini => ai.geminiApiKey,
      AiProvider.anthropic => ai.anthropicApiKey,
    };
    aiLine = key.trim().isEmpty
        ? StatusLine('No ${ai.provider.label} key', StatusTone.warning)
        : StatusLine('${ai.provider.label} · ${ai.activeModel}', StatusTone.ok);
  }

  final missing = config?.missingPersonalInfoLabels.length ?? 0;
  final StatusLine profile;
  if (config == null) {
    profile = const StatusLine('Loading…', StatusTone.neutral);
  } else if (config.isPersonalInfoComplete) {
    profile = const StatusLine('Profile complete', StatusTone.ok);
  } else {
    profile = StatusLine('$missing fields needed', StatusTone.warning);
  }

  final email = (calendar?.isConnected ?? false)
      ? calendar!.connectedEmail
      : user?.email;
  final signedIn = user != null || (calendar?.isConnected ?? false);
  final who = (email != null && email.trim().isNotEmpty) ? email : 'Signed in';
  final backupInfo = backup.value;
  final account = !signedIn
      ? const StatusLine('Not signed in', StatusTone.neutral)
      : StatusLine(
          backupInfo == null
              ? who
              : '$who · backed up '
                    '${DateFormat('d MMM').format(backupInfo.createdAt.toLocal())}',
          StatusTone.ok,
        );

  return SettingsStatus(
    ai: aiLine,
    profile: profile,
    account: account,
    profileMissingCount: missing,
  );
});
