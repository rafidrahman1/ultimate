import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:personal/features/settings/ai_settings_service.dart';

class AiClient {
  const AiClient({
    http.Client? httpClient,
    this.requestTimeout = const Duration(minutes: 5),
    this.maxAttempts = 4,
  }) : _httpClient = httpClient;

  final http.Client? _httpClient;
  final Duration requestTimeout;
  final int maxAttempts;

  Future<String> generate({
    required AiSettings settings,
    required String prompt,
    String? systemInstruction,
    Future<void> Function()? waitForResume,
  }) async {
    final client = _httpClient ?? http.Client();
    try {
      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          return await _generateOnce(
            client,
            settings: settings,
            prompt: prompt,
            systemInstruction: systemInstruction,
          ).timeout(requestTimeout);
        } catch (error) {
          lastError = error;
          if (!_isTransientNetworkError(error) || attempt == maxAttempts) {
            break;
          }

          if (waitForResume != null && _looksLikeBackgroundAbort(error)) {
            await waitForResume();
          } else {
            await Future<void>.delayed(
              Duration(seconds: 1 << (attempt - 1).clamp(0, 4)),
            );
          }
        }
      }

      throw Exception(_friendlyErrorMessage(lastError));
    } finally {
      if (_httpClient == null) {
        client.close();
      }
    }
  }

  Future<String> _generateOnce(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
    String? systemInstruction,
  }) {
    return switch (settings.provider) {
      AiProvider.openai => _generateOpenAi(
          client,
          settings: settings,
          prompt: prompt,
          systemInstruction: systemInstruction,
        ),
      AiProvider.gemini => _generateGemini(
          client,
          settings: settings,
          prompt: prompt,
          systemInstruction: systemInstruction,
        ),
    };
  }

  Future<String> _generateOpenAi(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
    String? systemInstruction,
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
        'temperature': 0.4,
        'messages': [
          if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
            {'role': 'system', 'content': systemInstruction.trim()},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _extractApiError(response.body);
      throw Exception(
        'OpenAI request failed (${response.statusCode})${error == null ? '' : ': $error'}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw Exception('OpenAI returned no choices.');
    }
    final message = choices.first['message'] as Map<String, dynamic>?;
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
    String? systemInstruction,
  }) async {
    final key = settings.geminiApiKey.trim();
    if (key.isEmpty) {
      throw Exception('Gemini API key is missing in Settings.');
    }

    final model = _normalizeGeminiModel(settings.geminiModel);
    final response = await client.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$model:generateContent?key=$key',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (systemInstruction != null && systemInstruction.trim().isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction.trim()},
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = _extractApiError(response.body);
      throw Exception(
        'Gemini request failed (${response.statusCode})${error == null ? '' : ': $error'}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = json['candidates'] as List<dynamic>? ?? const [];
    if (candidates.isEmpty) {
      throw Exception('Gemini returned no candidates.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
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

  String _normalizeGeminiModel(String rawModel) {
    final trimmed = rawModel.trim();
    if (trimmed.isEmpty) return 'gemini-1.5-flash';
    if (trimmed.startsWith('models/')) {
      return trimmed.substring('models/'.length);
    }
    return trimmed;
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
    } catch (_) {
      return null;
    }
  }

  bool _isTransientNetworkError(Object error) {
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
    return error is SocketException ||
        (error is http.ClientException &&
            message.contains('connection abort')) ||
        message.contains('connection abort');
  }

  String _friendlyErrorMessage(Object? error) {
    if (error == null) return 'AI request failed.';
    if (_looksLikeBackgroundAbort(error)) {
      return 'Analysis was interrupted because the app went to the background. '
          'Keep Personal open until analysis finishes.';
    }
    return error.toString();
  }
}
