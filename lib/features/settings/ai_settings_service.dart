import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal/core/app_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:personal/core/prefs.dart';

const _legacyAiSettingsStorageKey = 'ai_settings_v1';
const _providerStorageKey = 'ai_provider_v2';
const _openAiKeyStorageKey = 'ai_openai_key_v2';
const _openAiModelStorageKey = 'ai_openai_model_v2';
const _geminiKeyStorageKey = 'ai_gemini_key_v2';
const _geminiModelStorageKey = 'ai_gemini_model_v2';
const _anthropicKeyStorageKey = 'ai_anthropic_key_v2';
const _anthropicModelStorageKey = 'ai_anthropic_model_v2';
const _enableApiCallsStorageKey = 'ai_enable_api_calls_v2';

const defaultGeminiModel = 'gemini-2.5-flash';

enum AiProvider {
  openai('OpenAI'),
  gemini('Gemini'),
  anthropic('Claude');

  const AiProvider(this.label);

  final String label;
}

/// Gemini 1.0/1.5 models are retired and return 404; map stored values to
/// the current default so existing installs keep working.
String migrateGeminiModel(String model) {
  final normalized = model.trim().toLowerCase().replaceFirst('models/', '');
  if (normalized.startsWith('gemini-1.') || normalized == 'gemini-pro') {
    return defaultGeminiModel;
  }
  return model;
}

class AiSettings {
  const AiSettings({
    required this.provider,
    required this.openAiApiKey,
    required this.openAiModel,
    required this.geminiApiKey,
    required this.geminiModel,
    this.anthropicApiKey = '',
    this.anthropicModel = 'claude-opus-5-5',
    required this.enableApiCalls,
  });

  final AiProvider provider;
  final String openAiApiKey;
  final String openAiModel;
  final String geminiApiKey;
  final String geminiModel;
  final String anthropicApiKey;
  final String anthropicModel;
  final bool enableApiCalls;

  /// Model id for the currently selected [provider].
  String get activeModel => switch (provider) {
    AiProvider.openai => openAiModel,
    AiProvider.gemini => geminiModel,
    AiProvider.anthropic => anthropicModel,
  };

  factory AiSettings.initial() {
    return const AiSettings(
      provider: AiProvider.openai,
      openAiApiKey: '',
      openAiModel: 'gpt-5-mini',
      geminiApiKey: '',
      geminiModel: defaultGeminiModel,
      enableApiCalls: true,
    );
  }

  AiSettings copyWith({
    AiProvider? provider,
    String? openAiApiKey,
    String? openAiModel,
    String? geminiApiKey,
    String? geminiModel,
    String? anthropicApiKey,
    String? anthropicModel,
    bool? enableApiCalls,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openAiModel: openAiModel ?? this.openAiModel,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      anthropicModel: anthropicModel ?? this.anthropicModel,
      enableApiCalls: enableApiCalls ?? this.enableApiCalls,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'openAiApiKey': openAiApiKey,
    'openAiModel': openAiModel,
    'geminiApiKey': geminiApiKey,
    'geminiModel': geminiModel,
    'anthropicApiKey': anthropicApiKey,
    'anthropicModel': anthropicModel,
    'enableApiCalls': enableApiCalls,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final providerName = json['provider'] as String?;
    AiProvider? provider;
    for (final value in AiProvider.values) {
      if (value.name == providerName) {
        provider = value;
        break;
      }
    }
    return AiSettings(
      provider: provider ?? AiProvider.openai,
      openAiApiKey: json['openAiApiKey'] as String? ?? '',
      openAiModel:
          json['openAiModel'] as String? ?? AiSettings.initial().openAiModel,
      geminiApiKey: json['geminiApiKey'] as String? ?? '',
      geminiModel: migrateGeminiModel(
        json['geminiModel'] as String? ?? AiSettings.initial().geminiModel,
      ),
      anthropicApiKey: json['anthropicApiKey'] as String? ?? '',
      anthropicModel:
          json['anthropicModel'] as String? ??
          AiSettings.initial().anthropicModel,
      enableApiCalls: json['enableApiCalls'] as bool? ?? true,
    );
  }
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsNotifier, AiSettings>(
      AiSettingsNotifier.new,
    );

/// API keys live in the platform Keystore/Keychain via [FlutterSecureStorage];
/// every other (non-sensitive) field stays in SharedPreferences.
class AiSettingsNotifier extends AsyncNotifier<AiSettings> {
  static AiSettings _memoryFallback = AiSettings.initial();

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<AiSettings> build() async {
    final prefs = await safePrefs();
    if (prefs == null) {
      return _memoryFallback;
    }
    final providerName = prefs.getString(_providerStorageKey);

    if (providerName != null) {
      final loaded = await _fromSplitKeys(prefs, providerName);
      _memoryFallback = loaded;
      return loaded;
    }

    // Migration path from legacy JSON blob storage (keys were plaintext in
    // SharedPreferences at that point; move them into secure storage now).
    final legacyRaw = prefs.getString(_legacyAiSettingsStorageKey);
    if (legacyRaw == null || legacyRaw.isEmpty) return AiSettings.initial();
    try {
      final decoded = jsonDecode(legacyRaw) as Map<String, dynamic>;
      final migrated = AiSettings.fromJson(decoded);
      await _persistSplitKeys(prefs, migrated);
      _memoryFallback = migrated;
      return migrated;
    } catch (error) {
      AppLog.warn('Failed to decode legacy AI settings: $error');
      return _memoryFallback;
    }
  }

  Future<void> save(AiSettings settings) async {
    _memoryFallback = settings;
    final prefs = await safePrefs();
    if (prefs != null) {
      await _persistSplitKeys(prefs, settings);
    } else {
      AppLog.warn(
        'SharedPreferences unavailable. Using in-memory AI settings for this session.',
      );
    }
    state = AsyncData(settings);
  }

  Future<void> reset() => save(AiSettings.initial());

  Future<AiSettings> _fromSplitKeys(
    SharedPreferences prefs,
    String providerName,
  ) async {
    AiProvider? provider;
    for (final value in AiProvider.values) {
      if (value.name == providerName) {
        provider = value;
        break;
      }
    }

    final openAiApiKey = await _readKeyWithMigration(
      prefs: prefs,
      secureKey: _openAiKeyStorageKey,
    );
    final geminiApiKey = await _readKeyWithMigration(
      prefs: prefs,
      secureKey: _geminiKeyStorageKey,
    );
    final anthropicApiKey =
        await _safeSecureRead(_anthropicKeyStorageKey) ?? '';

    return AiSettings(
      provider: provider ?? AiProvider.openai,
      openAiApiKey: openAiApiKey,
      openAiModel:
          prefs.getString(_openAiModelStorageKey) ??
          AiSettings.initial().openAiModel,
      geminiApiKey: geminiApiKey,
      geminiModel: migrateGeminiModel(
        prefs.getString(_geminiModelStorageKey) ??
            AiSettings.initial().geminiModel,
      ),
      anthropicApiKey: anthropicApiKey,
      anthropicModel:
          prefs.getString(_anthropicModelStorageKey) ??
          AiSettings.initial().anthropicModel,
      enableApiCalls: prefs.getBool(_enableApiCallsStorageKey) ?? true,
    );
  }

  /// Reads an API key from secure storage; if it's missing there but still
  /// present in SharedPreferences from before the secure-storage migration,
  /// moves it over and scrubs the plaintext copy.
  Future<String> _readKeyWithMigration({
    required SharedPreferences prefs,
    required String secureKey,
  }) async {
    final secureValue = await _safeSecureRead(secureKey);
    if (secureValue != null && secureValue.isNotEmpty) return secureValue;

    final plaintextValue = prefs.getString(secureKey);
    if (plaintextValue == null || plaintextValue.isEmpty) return '';

    await _safeSecureWrite(secureKey, plaintextValue);
    await prefs.remove(secureKey);
    return plaintextValue;
  }

  Future<void> _persistSplitKeys(
    SharedPreferences prefs,
    AiSettings settings,
  ) async {
    final results = await Future.wait<bool>([
      prefs.setString(_providerStorageKey, settings.provider.name),
      prefs.setString(_openAiModelStorageKey, settings.openAiModel),
      prefs.setString(_geminiModelStorageKey, settings.geminiModel),
      prefs.setString(_anthropicModelStorageKey, settings.anthropicModel),
      prefs.setBool(_enableApiCallsStorageKey, settings.enableApiCalls),
      // Clear any pre-migration plaintext keys still sitting in prefs.
      prefs.remove(_openAiKeyStorageKey),
      prefs.remove(_geminiKeyStorageKey),
    ]);

    if (results.any((ok) => !ok)) {
      AppLog.warn(
        'Could not persist all AI settings values to SharedPreferences.',
      );
    }

    await _safeSecureWrite(_openAiKeyStorageKey, settings.openAiApiKey);
    await _safeSecureWrite(_geminiKeyStorageKey, settings.geminiApiKey);
    await _safeSecureWrite(_anthropicKeyStorageKey, settings.anthropicApiKey);
  }

  Future<String?> _safeSecureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (error) {
      AppLog.warn('Secure storage read failed for $key: $error');
      return null;
    }
  }

  Future<void> _safeSecureWrite(String key, String value) async {
    try {
      if (value.isEmpty) {
        await _secureStorage.delete(key: key);
      } else {
        await _secureStorage.write(key: key, value: value);
      }
    } catch (error) {
      AppLog.warn('Secure storage write failed for $key: $error');
    }
  }
}
