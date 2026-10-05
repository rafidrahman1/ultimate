import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal/core/backup_service.dart';
import 'package:personal/core/data_folder_settings_service.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/calendar/calendar_settings_service.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// How healthy a settings area is, for the hub rows and drawer badges.
enum StatusTone { ok, warning, neutral }

/// One-line summary of an area, e.g. "Folder set · Backed up 2 h ago".
class StatusLine {
  const StatusLine(this.text, this.tone);

  final String text;
  final StatusTone tone;
}

/// Last backup in the data folder, if any. Refresh with `ref.invalidate`.
final backupInfoProvider = FutureProvider.autoDispose<BackupInfo?>(
  (ref) => const BackupService().peek(),
);

/// Status of each settings area, derived from the live providers.
class SettingsStatus {
  const SettingsStatus({
    required this.storage,
    required this.ai,
    required this.profile,
    required this.account,
    required this.profileMissingCount,
  });

  final StatusLine storage;
  final StatusLine ai;
  final StatusLine profile;
  final StatusLine account;
  final int profileMissingCount;

  /// Areas that need the user's attention.
  int get warningCount => [
    storage,
    ai,
    profile,
    account,
  ].where((s) => s.tone == StatusTone.warning).length;
}

final settingsStatusProvider = Provider<SettingsStatus>((ref) {
  final folder = ref.watch(dataFolderSettingsProvider).valueOrNull;
  final ai = ref.watch(aiSettingsProvider).valueOrNull;
  final config = ref.watch(promptConfigProvider).valueOrNull;
  final calendar = ref.watch(calendarSettingsProvider).valueOrNull;
  final user = ref.watch(authStateProvider).valueOrNull;

  final StatusLine storage;
  if (folder == null || !folder.hasFolder) {
    storage = const StatusLine('No data folder chosen', StatusTone.warning);
  } else if (folder.needsReselect) {
    storage = const StatusLine('Choose the folder again', StatusTone.warning);
  } else {
    storage = const StatusLine('Folder set', StatusTone.ok);
  }

  final StatusLine aiLine;
  if (ai == null) {
    aiLine = const StatusLine('Loading…', StatusTone.neutral);
  } else if (!ai.enableApiCalls) {
    aiLine = const StatusLine('Local insights only', StatusTone.neutral);
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
  final account = (email != null && email.trim().isNotEmpty)
      ? StatusLine(email, StatusTone.ok)
      : (user != null || (calendar?.isConnected ?? false))
      ? const StatusLine('Signed in', StatusTone.ok)
      : const StatusLine('Not signed in', StatusTone.neutral);

  return SettingsStatus(
    storage: storage,
    ai: aiLine,
    profile: profile,
    account: account,
    profileMissingCount: missing,
  );
});
