import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:personal/core/app_log.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

/// Lets the UI abort an in-flight analysis request.
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
  String toString() => 'Analysis cancelled.';
}

/// Non-2xx response from a provider. [isRetryable] covers rate limits,
/// overload, and server errors; 4xx request errors fail immediately.
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
      401 || 403 => ' Check the API key in Settings.',
      404 => ' Check the model name in Settings.',
      429 => ' The provider is rate limiting requests; try again shortly.',
      _ => '',
    };
    return '$provider request failed ($statusCode)'
        '${detail == null ? '' : ': $detail'}.$hint';
  }
}

class AiClient {
  const AiClient({
    http.Client? httpClient,
    this.requestTimeout = const Duration(minutes: 4),
    this.totalBudget = const Duration(minutes: 10),
    this.maxAttempts = 4,
  }) : _httpClient = httpClient;

  final http.Client? _httpClient;

  /// Per-attempt limit.
  final Duration requestTimeout;

  /// Wall-clock limit across all attempts and backoff waits.
  final Duration totalBudget;
  final int maxAttempts;

  static const _maxBackoff = Duration(seconds: 60);

  Future<String> generate({
    required AiSettings settings,
    required String prompt,
    String? systemInstruction,
    Future<void> Function()? waitForResume,
    AiCancelToken? cancelToken,
  }) async {
    final ownsClient = _httpClient == null;
    final client = _httpClient ?? http.Client();
    // Closing the client aborts any in-flight request immediately.
    if (ownsClient) {
      unawaited(cancelToken?.whenCancelled.then((_) => client.close()));
    }

    final clock = Stopwatch()..start();
    try {
      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        _throwIfCancelled(cancelToken);
        try {
          return await _raceCancel(
            _generateOnce(
              client,
              settings: settings,
              prompt: prompt,
              systemInstruction: systemInstruction,
            ).timeout(requestTimeout),
            cancelToken,
          );
        } catch (error) {
          if (cancelToken?.isCancelled ?? false) {
            throw const AiCancelledException();
          }
          lastError = error;
          if (!_isRetryable(error) || attempt == maxAttempts) break;

          if (waitForResume != null && _looksLikeBackgroundAbort(error)) {
            await _raceCancel(waitForResume(), cancelToken);
            continue;
          }

          final delay = _backoff(error, attempt);
          if (clock.elapsed + delay > totalBudget) break;
          AppLog.warn(
            'AI request attempt $attempt failed ($error); '
            'retrying in ${delay.inSeconds}s',
          );
          await _raceCancel(Future<void>.delayed(delay), cancelToken);
        }
      }

      throw Exception(_friendlyErrorMessage(lastError));
    } finally {
      if (ownsClient) client.close();
    }
  }

  Future<String> _generateOnce(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
    String? systemInstruction,
  }) {
    final system = systemInstruction?.trim();
    final hasSystem = system != null && system.isNotEmpty;
    return switch (settings.provider) {
      AiProvider.openai => _generateOpenAi(
        client,
        settings: settings,
        prompt: prompt,
        system: hasSystem ? system : null,
      ),
      AiProvider.gemini => _generateGemini(
        client,
        settings: settings,
        prompt: prompt,
        system: hasSystem ? system : null,
      ),
      AiProvider.anthropic => _generateAnthropic(
        client,
        settings: settings,
        prompt: prompt,
        system: hasSystem ? system : null,
      ),
    };
  }

  Future<String> _generateOpenAi(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
    String? system,
  }) async {
    final key = settings.openAiApiKey.trim();
    if (key.isEmpty) {
      throw Exception('OpenAI API key is missing in Settings.');
    }

    final response = await client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': settings.openAiModel,
        if (_supportsCustomTemperature(settings.openAiModel))
          'temperature': 0.4,
        'messages': [
          if (system != null) {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );
    _throwIfError('OpenAI', response.statusCode, response.body, response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw Exception('OpenAI returned no choices.');
    }
    final message =
        (choices.first as Map<String, dynamic>)['message']
            as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('OpenAI returned empty content.');
    }
    return content.trim();
  }

  Future<String> _generateGemini(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
    String? system,
  }) async {
    final key = settings.geminiApiKey.trim();
    if (key.isEmpty) {
      throw Exception('Gemini API key is missing in Settings.');
    }

    final model = _normalizeGeminiModel(settings.geminiModel);
    final response = await client.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent',
      ),
      // Header rather than ?key= so the key never lands in URL logs.
      headers: {'Content-Type': 'application/json', 'x-goog-api-key': key},
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
      }),
    );
    _throwIfError('Gemini', response.statusCode, response.body, response);

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }

    final content =
        (candidates.first as Map<String, dynamic>)['content']
            as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final text = parts
        .whereType<Map>()
        .map((part) => part['text']?.toString() ?? '')
        .join('\n')
        .trim();
    if (text.isEmpty) {
      throw Exception('Gemini returned empty content.');
    }
    return text;
  }

  /// Claude Messages API over SSE streaming, so long reports don't sit on an
  /// idle connection that mobile networks or proxies may drop.
  Future<String> _generateAnthropic(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
    String? system,
  }) async {
    final key = settings.anthropicApiKey.trim();
    if (key.isEmpty) {
      throw Exception('Anthropic API key is missing in Settings.');
    }

    final model = settings.anthropicModel.trim();
    final modern = _supportsEffortAndFallbacks(model);
    final request =
        http.Request('POST', Uri.parse('https://api.anthropic.com/v1/messages'))
          ..headers.addAll({
            'Content-Type': 'application/json',
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            // Server-side refusal fallback: a declined request is re-run on
            // Anthropic's recommended fallback model instead of failing.
            if (modern) 'anthropic-beta': 'server-side-fallback-2026-07-01',
          })
          ..body = jsonEncode({
            'model': model,
            'max_tokens': 64000,
            'stream': true,
            'system': ?system,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            if (modern) ...{
              'output_config': {'effort': 'high'},
              'fallbacks': 'default',
            },
          });

    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      _throwIfError('Claude', response.statusCode, body, response);
    }

    final text = StringBuffer();
    String? stopReason;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;

      final event = jsonDecode(payload);
      if (event is! Map) continue;
      switch (event['type']) {
        case 'content_block_start':
          final block = event['content_block'];
          // A fallback block marks a hand-off after a mid-stream refusal;
          // discard the declined model's partial text.
          if (block is Map && block['type'] == 'fallback') text.clear();
        case 'content_block_delta':
          final delta = event['delta'];
          if (delta is Map && delta['type'] == 'text_delta') {
            text.write(delta['text'] ?? '');
          }
        case 'message_delta':
          final delta = event['delta'];
          if (delta is Map && delta['stop_reason'] != null) {
            stopReason = delta['stop_reason'].toString();
          }
        case 'error':
          final error = event['error'];
          final type = error is Map ? error['type']?.toString() : null;
          throw AiHttpException(
            provider: 'Claude',
            statusCode: switch (type) {
              'overloaded_error' => 529,
              'rate_limit_error' => 429,
              'api_error' => 500,
              _ => 400,
            },
            detail: error is Map ? error['message']?.toString() : null,
          );
      }
    }

    if (stopReason == 'refusal') {
      throw Exception(
        'Claude declined this request. Try again, or switch provider in '
        'Settings.',
      );
    }
    if (stopReason == 'max_tokens') {
      throw Exception(
        'Claude hit the output limit before finishing the report.',
      );
    }
    final result = text.toString().trim();
    if (result.isEmpty) {
      throw Exception('Claude returned empty content.');
    }
    return result;
  }

  /// Models that accept `output_config.effort` and the `fallbacks` param.
  bool _supportsEffortAndFallbacks(String model) {
    const prefixes = ['claude-opus-5', 'claude-fable-5', 'claude-sonnet-5-5'];
    return prefixes.any(model.startsWith);
  }

  bool _supportsCustomTemperature(String model) {
    final normalized = model.trim().toLowerCase();
    // Reasoning models (o1/o3/o4/gpt-5 families) only accept the default
    // temperature (1) and reject an explicit value with a 400 error.
    const reasoningPrefixes = ['o1', 'o3', 'o4', 'gpt-5'];
    return !reasoningPrefixes.any((prefix) => normalized.startsWith(prefix));
  }

  String _normalizeGeminiModel(String rawModel) {
    final trimmed = migrateGeminiModel(rawModel.trim());
    if (trimmed.isEmpty) return defaultGeminiModel;
    if (trimmed.startsWith('models/')) {
      return trimmed.substring('models/'.length);
    }
    return trimmed;
  }

  void _throwIfError(
    String provider,
    int statusCode,
    String body,
    http.BaseResponse response,
  ) {
    if (statusCode >= 200 && statusCode < 300) return;
    throw AiHttpException(
      provider: provider,
      statusCode: statusCode,
      detail: _extractApiError(body),
      retryAfter: _parseRetryAfter(response.headers['retry-after']),
    );
  }

  Duration? _parseRetryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }

  Duration _backoff(Object error, int attempt) {
    final hinted = error is AiHttpException ? error.retryAfter : null;
    final exponential = Duration(seconds: 1 << min(attempt - 1, 5));
    final delay = hinted ?? exponential;
    return delay > _maxBackoff ? _maxBackoff : delay;
  }

  String? _extractApiError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final error = decoded['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      return null;
    } catch (error) {
      AppLog.warn('Failed to parse API error body: $error');
      return null;
    }
  }

  bool _isRetryable(Object error) {
    if (error is AiHttpException) return error.isRetryable;
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is http.ClientException) return true;

    final message = error.toString().toLowerCase();
    return message.contains('connection abort') ||
        message.contains('connection reset') ||
        message.contains('broken pipe') ||
        message.contains('network is unreachable') ||
        message.contains('timed out');
  }

  bool _looksLikeBackgroundAbort(Object error) {
    final message = error.toString().toLowerCase();
    return error is SocketException || message.contains('connection abort');
  }

  void _throwIfCancelled(AiCancelToken? token) {
    if (token?.isCancelled ?? false) throw const AiCancelledException();
  }

  Future<T> _raceCancel<T>(Future<T> future, AiCancelToken? token) {
    if (token == null) return future;
    return Future.any([
      future,
      token.whenCancelled.then<T>((_) => throw const AiCancelledException()),
    ]);
  }

  String _friendlyErrorMessage(Object? error) {
    if (error == null) return 'AI request failed.';
    if (_looksLikeBackgroundAbort(error)) {
      return 'Analysis was interrupted because the app went to the background. '
          'Keep Personal open until analysis finishes.';
    }
    if (error is TimeoutException) {
      return 'The AI provider took too long to respond. Try again, or pick a '
          'faster model in Settings.';
    }
    return error.toString();
  }
}
