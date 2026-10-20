import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/core/storage/prefs.dart';

enum AiProvider {
  openai('OpenAI', 'gpt-5-mini'),
  gemini('Gemini', 'gemini-2.5-flash'),
  anthropic('Claude', 'claude-sonnet-5-5');

  const AiProvider(this.label, this.defaultModel);

  final String label;
  final String defaultModel;
}

class AiSettings {
  const AiSettings({
    this.provider = AiProvider.anthropic,
    this.keys = const {},
    this.models = const {},
    this.webSearch = true,
  });

  final AiProvider provider;
  final Map<AiProvider, String> keys;
  final Map<AiProvider, String> models;

  /// Let Claude and Gemini look the bike up on the web while answering, which
  /// grounds service intervals in published figures. OpenAI ignores this.
  final bool webSearch;

  String keyOf(AiProvider p) => keys[p]?.trim() ?? '';
  String modelOf(AiProvider p) {
    final m = models[p]?.trim() ?? '';
    return m.isEmpty ? p.defaultModel : m;
  }

  String get apiKey => keyOf(provider);
  String get model => modelOf(provider);
  bool get isConfigured => apiKey.isNotEmpty;

  AiSettings copyWith({
    AiProvider? provider,
    Map<AiProvider, String>? keys,
    Map<AiProvider, String>? models,
    bool? webSearch,
  }) => AiSettings(
    provider: provider ?? this.provider,
    keys: keys ?? this.keys,
    models: models ?? this.models,
    webSearch: webSearch ?? this.webSearch,
  );
}

final aiSettingsProvider =
    AsyncNotifierProvider<AiSettingsNotifier, AiSettings>(
      AiSettingsNotifier.new,
    );

/// API keys live in the platform Keystore/Keychain; the rest (provider, model
/// names, web-search switch) is kept in SharedPreferences.
class AiSettingsNotifier extends AsyncNotifier<AiSettings> {
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _providerKey = 'ai_provider_v1';
  static const _webKey = 'ai_web_search_v1';
  static String _keyName(AiProvider p) => 'ai_key_${p.name}_v1';
  static String _modelName(AiProvider p) => 'ai_model_${p.name}_v1';

  static AiSettings _memory = const AiSettings();

  @override
  Future<AiSettings> build() async {
    final prefs = await safePrefs();
    if (prefs == null) return _memory;
    final keys = <AiProvider, String>{};
    final models = <AiProvider, String>{};
    for (final p in AiProvider.values) {
      try {
        final k = await _secure.read(key: _keyName(p));
        if (k != null && k.isNotEmpty) keys[p] = k;
      } catch (error) {
        AppLog.warn('Secure storage read failed: $error');
      }
      final m = prefs.getString(_modelName(p));
      if (m != null && m.isNotEmpty) models[p] = m;
    }
    final name = prefs.getString(_providerKey);
    final loaded = AiSettings(
      provider: AiProvider.values.firstWhere(
        (p) => p.name == name,
        orElse: () => AiProvider.anthropic,
      ),
      keys: keys,
      models: models,
      webSearch: prefs.getBool(_webKey) ?? true,
    );
    _memory = loaded;
    return loaded;
  }

  Future<void> save(AiSettings next) async {
    _memory = next;
    state = AsyncData(next);
    final prefs = await safePrefs();
    await prefs?.setString(_providerKey, next.provider.name);
    await prefs?.setBool(_webKey, next.webSearch);
    for (final p in AiProvider.values) {
      await prefs?.setString(_modelName(p), next.models[p]?.trim() ?? '');
      try {
        final key = next.keyOf(p);
        if (key.isEmpty) {
          await _secure.delete(key: _keyName(p));
        } else {
          await _secure.write(key: _keyName(p), value: key);
        }
      } catch (error) {
        AppLog.warn('Secure storage write failed: $error');
      }
    }
  }
}
