import 'dart:convert';

import 'package:http/http.dart' as http;

import '../settings/ai_settings_service.dart';

class AiClient {
  const AiClient({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  Future<String> generate({
    required AiSettings settings,
    required String prompt,
  }) async {
    final client = _httpClient ?? http.Client();
    try {
      return switch (settings.provider) {
        AiProvider.openai => _generateOpenAi(client, settings: settings, prompt: prompt),
        AiProvider.gemini => _generateGemini(client, settings: settings, prompt: prompt),
      };
    } finally {
      if (_httpClient == null) {
        client.close();
      }
    }
  }

  Future<String> _generateOpenAi(
    http.Client client, {
    required AiSettings settings,
    required String prompt,
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
          {
            'role': 'user',
            'content': prompt,
          },
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
}
