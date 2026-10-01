import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal/core/app_log.dart';
import 'package:personal/core/weekday_schedule.dart';
import 'package:personal/features/auth/google_account_service.dart';
import 'package:personal/features/prompts/personal_info_firestore_service.dart';
import 'package:personal/features/prompts/prompt_template_sections.dart';

part 'prompt_config_model.dart';

const _promptConfigStorageKey = 'prompt_config_v2';
const _legacyPromptConfigStorageKey = 'prompt_config_v1';
const _personalInfoLocalUpdatedAtKey = 'personal_info_local_updated_at_ms';

class PromptConfigSaveResult {
  const PromptConfigSaveResult({
    required this.savedLocally,
    this.syncedToCloud = false,
    this.syncError,
  });

  final bool savedLocally;
  final bool syncedToCloud;
  final String? syncError;
}

class PersonalInfoSyncResult {
  const PersonalInfoSyncResult({
    this.synced = false,
    this.noCloudData = false,
    this.notSignedIn = false,
    this.error,
  });

  final bool synced;
  final bool noCloudData;
  final bool notSignedIn;
  final String? error;
}

final promptConfigProvider =
    AsyncNotifierProvider<PromptConfigNotifier, PromptConfig>(
      PromptConfigNotifier.new,
    );

class PromptConfigNotifier extends AsyncNotifier<PromptConfig> {
  @override
  Future<PromptConfig> build() async {
    final local = await _loadLocal();
    return _syncFromCloudIfNeeded(local);
  }

  Future<PromptConfig> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_promptConfigStorageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return PromptConfig.fromJson(decoded);
      } catch (error) {
        AppLog.warn('Failed to decode prompt config: $error');
        return PromptConfig.initial();
      }
    }

    final legacyRaw = prefs.getString(_legacyPromptConfigStorageKey);
    if (legacyRaw != null && legacyRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacyRaw) as Map<String, dynamic>;
        return PromptConfig.fromLegacyJson(decoded);
      } catch (error) {
        AppLog.warn('Failed to decode legacy prompt config: $error');
        return PromptConfig.initial();
      }
    }

    return PromptConfig.initial();
  }

  Future<void> _saveLocal(PromptConfig next, {DateTime? updatedAt}) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promptConfigStorageKey, jsonEncode(next.toJson()));
    await prefs.setInt(
      _personalInfoLocalUpdatedAtKey,
      (updatedAt ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  DateTime? _readLocalUpdatedAt(SharedPreferences prefs) {
    final millis = prefs.getInt(_personalInfoLocalUpdatedAtKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<PromptConfig> _syncFromCloudIfNeeded(PromptConfig local) async {
    final auth = ref.read(googleAccountServiceProvider);
    final user = auth.currentUser;
    if (user == null) return local;

    try {
      final firestore = ref.read(personalInfoFirestoreServiceProvider);
      final cloud = await firestore.loadPersonalInfo(user.uid);
      if (cloud == null) {
        if (local.hasAnyPersonalInfo) {
          await firestore.savePersonalInfo(user.uid, local);
        }
        return local;
      }

      final prefs = await SharedPreferences.getInstance();
      final localUpdatedAt = _readLocalUpdatedAt(prefs);
      final cloudUpdatedAt = cloud.updatedAt;

      if (cloudUpdatedAt != null &&
          (localUpdatedAt == null || cloudUpdatedAt.isAfter(localUpdatedAt))) {
        final merged = local.mergePersonalInfo(cloud.data);
        await _saveLocal(merged, updatedAt: cloudUpdatedAt);
        return merged;
      }

      return local;
    } catch (error) {
      AppLog.warn('Failed to sync prompt config from cloud: $error');
      return local;
    }
  }

  Future<void> syncFromCloud() async {
    final current = state.valueOrNull ?? await _loadLocal();
    final synced = await _syncFromCloudIfNeeded(current);
    if (synced != current) {
      state = AsyncData(synced);
    }
  }

  Future<PersonalInfoSyncResult> pullPersonalInfoFromCloud() async {
    final auth = ref.read(googleAccountServiceProvider);
    final user = auth.currentUser;
    if (user == null) {
      return const PersonalInfoSyncResult(notSignedIn: true);
    }

    try {
      final firestore = ref.read(personalInfoFirestoreServiceProvider);
      final current = state.valueOrNull ?? await _loadLocal();
      final cloud = await firestore.loadPersonalInfo(user.uid);
      if (cloud == null) {
        return const PersonalInfoSyncResult(noCloudData: true);
      }

      final merged = current.mergePersonalInfo(cloud.data);
      await _saveLocal(merged, updatedAt: cloud.updatedAt);
      return const PersonalInfoSyncResult(synced: true);
    } catch (error) {
      return PersonalInfoSyncResult(error: error.toString());
    }
  }

  Future<PromptConfigSaveResult> save(
    PromptConfig next, {
    bool syncToCloud = true,
  }) async {
    await _saveLocal(next);

    if (!syncToCloud) {
      return const PromptConfigSaveResult(savedLocally: true);
    }

    final auth = ref.read(googleAccountServiceProvider);
    final user = auth.currentUser;
    if (user == null) {
      return const PromptConfigSaveResult(savedLocally: true);
    }

    try {
      final firestore = ref.read(personalInfoFirestoreServiceProvider);
      final cloudUpdatedAt = await firestore.savePersonalInfo(user.uid, next);
      if (cloudUpdatedAt != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _personalInfoLocalUpdatedAtKey,
          cloudUpdatedAt.millisecondsSinceEpoch,
        );
      }
      return const PromptConfigSaveResult(
        savedLocally: true,
        syncedToCloud: true,
      );
    } catch (error) {
      return PromptConfigSaveResult(
        savedLocally: true,
        syncError: error.toString(),
      );
    }
  }

  Future<void> reset({bool syncToCloud = true}) =>
      save(PromptConfig.initial(), syncToCloud: syncToCloud);
}
