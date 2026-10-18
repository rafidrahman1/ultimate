import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:motohealth/core/app_log.dart';
import 'package:motohealth/features/ai/ai_settings.dart';

/// Lets the UI abort an in-flight request.
class AiCancelToken {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

class AiCancelledException implements Exception {
  const AiCancelledException();

  @override
  String toString() => 'Cancelled.';
}

/// A non-2xx answer from a provider. Rate limits, overload and server errors
/// are retried; other 4xx errors fail at once.
class AiHttpException implements Exception {
  const AiHttpException({
    required this.provider,
    required this.statusCode,
    this.detail,
    this.retryAfter,
  });

  final String provider;
  final int statusCode;
  final String? detail;
  final Duration? retryAfter;

  bool get isRetryable =>
      statusCode == 408 ||
      statusCode == 409 ||
      statusCode == 429 ||
      statusCode >= 500;

  @override
  String toString() {
    final hint = switch (statusCode) {
      401 || 403 => ' Check the API key in AI settings.',
      404 => ' Check the model name in AI settings.',
      429 => ' The provider is rate limiting; try again shortly.',
      _ => '',
    };
    return '$provider request failed ($statusCode)'
        '${detail == null ? '' : ': $detail'}.$hint';
  }
}

/// Sends one prompt to OpenAI, Gemini or Claude and returns the text answer.
class AiClient {
  const AiClient({
    http.Client? httpClient,
    this.requestTimeout = const Duration(minutes: 3),
    this.totalBudget = const Duration(minutes: 6),
    this.maxAttempts = 3,
  }) : _httpClient = httpClient;

  final http.Client? _httpClient;
  final Duration requestTimeout;
  final Duration totalBudget;
  final int maxAttempts;

  static const _maxBackoff = Duration(seconds: 45);

  Future<String> generate({
    required AiSettings settings,
    required String prompt,
    String? system,
    bool webSearch = false,
    AiCancelToken? cancelToken,
  }) async {
    if (!settings.isConfigured) {
      throw Exception(
        'Add a ${settings.provider.label} API key in AI settings first.',
      );
    }
    final ownsClient = _httpClient == null;
    final client = _httpClient ?? http.Client();
    if (ownsClient) {
      unawaited(cancelToken?.whenCancelled.then((_) => client.close()));
    }
    final clock = Stopwatch()..start();
    var search = webSearch && settings.webSearch;
    try {
      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        if (cancelToken?.isCancelled ?? false) {
          throw const AiCancelledException();
        }
        try {
          return await _race(
            _once(
              client,
              settings: settings,
              prompt: prompt,
              system: system,
              webSearch: search,
            ).timeout(requestTimeout),
            cancelToken,
          );
        } catch (error) {
          if (cancelToken?.isCancelled ?? false) {
            throw const AiCancelledException();
          }
          lastError = error;
          // A model that rejects the search tool still answers without it.
          if (search && error is AiHttpException && error.statusCode == 400) {
            search = false;
            continue;
          }
          if (!_isRetryable(error) || attempt == maxAttempts) break;
          final delay = _backoff(error, attempt);
          if (clock.elapsed + delay > totalBudget) break;
          AppLog.warn('AI attempt $attempt failed ($error); retrying');
          await _race(Future<void>.delayed(delay), cancelToken);
        }
      }
      throw Exception(_friendly(lastError));
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<String> _once(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
    required bool webSearch,
    String? system,
  }) {
    final sys = system?.trim();
    final s = (sys == null || sys.isEmpty) ? null : sys;
    return switch (settings.provider) {
      AiProvider.openai => _openAi(client, settings, prompt, s),
      AiProvider.gemini => _gemini(client, settings, prompt, s, webSearch),
      AiProvider.anthropic => _anthropic(
        client,
        settings,
        prompt,
        s,
        webSearch,
      ),
    };
  }

  Future<String> _openAi(
    http.Client client,
    AiSettings settings,
    String prompt,
    String? system,
  ) async {
    final model = settings.model;
    final reasoning = [
      'o1',
      'o3',
      'o4',
      'gpt-5',
    ].any(model.toLowerCase().startsWith);
    final response = await client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer ${settings.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model,
        if (!reasoning) 'temperature': 0.2,
        'messages': [
          if (system != null) {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );
    _check('OpenAI', response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List? ?? const [];
    final message = choices.isEmpty
        ? null
        : (choices.first as Map)['message'] as Map?;
    return _nonEmpty('OpenAI', message?['content'] as String?);
  }

  Future<String> _gemini(
    http.Client client,
    AiSettings settings,
    String prompt,
    String? system,
    bool webSearch,
  ) async {
    var model = settings.model;
    if (model.startsWith('models/')) model = model.substring(7);
    final response = await client.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent',
      ),
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': settings.apiKey,
      },
      body: jsonEncode({
        if (system != null)
          'systemInstruction': {
            'parts': [
              {'text': system},
            ],
          },
        'contents': [
          {
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.2},
        if (webSearch)
          'tools': [
            {'google_search': <String, dynamic>{}},
          ],
      }),
    );
    _check('Gemini', response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List? ?? const [];
    final content = candidates.isEmpty
        ? null
        : (candidates.first as Map)['content'] as Map?;
    final parts = content?['parts'] as List? ?? const [];
    final text = parts.whereType<Map>().map((p) => p['text'] ?? '').join('\n');
    return _nonEmpty('Gemini', text);
  }

  Future<String> _anthropic(
    http.Client client,
    AiSettings settings,
    String prompt,
    String? system,
    bool webSearch,
  ) async {
    final response = await client.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': settings.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': settings.model,
        'max_tokens': 8000,
        'system': ?system,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        if (webSearch)
          'tools': [
            {
              'type': 'web_search_20250305',
              'name': 'web_search',
              'max_uses': 5,
            },
          ],
      }),
    );
    _check('Claude', response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['stop_reason'] == 'refusal') {
      throw Exception('Claude declined this request.');
    }
    final blocks = json['content'] as List? ?? const [];
    final text = blocks
        .whereType<Map>()
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] ?? '')
        .join('\n');
    return _nonEmpty('Claude', text);
  }

  String _nonEmpty(String provider, String? text) {
    final t = text?.trim() ?? '';
    if (t.isEmpty) throw Exception('$provider returned an empty answer.');
    return t;
  }

  void _check(String provider, http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String? detail;
    try {
      final decoded = jsonDecode(response.body);
      final error = decoded is Map ? decoded['error'] : null;
      if (error is Map) detail = error['message']?.toString();
    } catch (_) {
      // Body was not JSON; the status code is enough.
    }
    final seconds = int.tryParse(response.headers['retry-after']?.trim() ?? '');
    throw AiHttpException(
      provider: provider,
      statusCode: response.statusCode,
      detail: detail,
      retryAfter: seconds == null ? null : Duration(seconds: seconds),
    );
  }

  Duration _backoff(Object error, int attempt) {
    final hinted = error is AiHttpException ? error.retryAfter : null;
    final delay = hinted ?? Duration(seconds: 1 << min(attempt, 5));
    return delay > _maxBackoff ? _maxBackoff : delay;
  }

  bool _isRetryable(Object error) {
    if (error is AiHttpException) return error.isRetryable;
    return error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException;
  }

  Future<T> _race<T>(Future<T> future, AiCancelToken? token) {
    if (token == null) return future;
    return Future.any([
      future,
      token.whenCancelled.then<T>((_) => throw const AiCancelledException()),
    ]);
  }

  String _friendly(Object? error) {
    if (error is TimeoutException) {
      return 'The AI provider took too long to answer. Try again.';
    }
    if (error is SocketException || error is http.ClientException) {
      return 'No connection to the AI provider. Check your internet.';
    }
    return error?.toString().replaceFirst('Exception: ', '') ??
        'The AI request failed.';
  }
}

final aiClient = const AiClient();
