import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

AiSettings _settings(AiProvider provider) => AiSettings.initial().copyWith(
  provider: provider,
  openAiApiKey: 'sk-test',
  geminiApiKey: 'gm-test',
  anthropicApiKey: 'sk-ant-test',
);

String _openAiBody(String text) => jsonEncode({
  'choices': [
    {
      'message': {'content': text},
    },
  ],
});

void main() {
  test('retries 429 using Retry-After, then succeeds', () async {
    var calls = 0;
    final client = AiClient(
      httpClient: MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response(
            '{"error":{"message":"slow down"}}',
            429,
            headers: {'retry-after': '0'},
          );
        }
        return http.Response(_openAiBody('report'), 200);
      }),
    );

    final output = await client.generate(
      settings: _settings(AiProvider.openai),
      prompt: 'p',
    );

    expect(output, 'report');
    expect(calls, 2);
  });

  test('does not retry a 400', () async {
    var calls = 0;
    final client = AiClient(
      httpClient: MockClient((request) async {
        calls++;
        return http.Response('{"error":{"message":"bad model"}}', 400);
      }),
    );

    await expectLater(
      client.generate(settings: _settings(AiProvider.openai), prompt: 'p'),
      throwsA(predicate((e) => e.toString().contains('bad model'))),
    );
    expect(calls, 1);
  });

  test('Gemini key goes in a header, not the URL', () async {
    late http.Request seen;
    final client = AiClient(
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'ok'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    await client.generate(
      settings: _settings(
        AiProvider.gemini,
      ).copyWith(geminiModel: 'gemini-1.5-flash'),
      prompt: 'p',
    );

    expect(seen.url.queryParameters, isEmpty);
    expect(seen.headers['x-goog-api-key'], 'gm-test');
    expect(seen.url.path, contains(defaultGeminiModel));
  });

  test(
    'Claude SSE stream is assembled and fallback discards partial text',
    () async {
      late http.Request seen;
      String event(Map<String, Object?> data) =>
          'event: ${data['type']}\ndata: ${jsonEncode(data)}\n\n';
      final sse = [
        event({
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'text', 'text': ''},
        }),
        event({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'declined partial'},
        }),
        event({
          'type': 'content_block_start',
          'index': 1,
          'content_block': {'type': 'fallback'},
        }),
        event({
          'type': 'content_block_delta',
          'index': 2,
          'delta': {'type': 'text_delta', 'text': '### Report'},
        }),
        event({
          'type': 'message_delta',
          'delta': {'stop_reason': 'end_turn'},
        }),
      ].join();

      final client = AiClient(
        httpClient: MockClient.streaming((request, body) async {
          seen = request as http.Request;
          return http.StreamedResponse(Stream.value(utf8.encode(sse)), 200);
        }),
      );

      final output = await client.generate(
        settings: _settings(AiProvider.anthropic),
        prompt: 'p',
        systemInstruction: 'sys',
      );

      expect(output, '### Report');
      expect(seen.headers['x-api-key'], 'sk-ant-test');
      final body = jsonDecode(seen.body) as Map<String, dynamic>;
      expect(body['model'], 'claude-opus-5-5');
      expect(body['system'], 'sys');
      expect(body['stream'], isTrue);
      expect(body['fallbacks'], 'default');
    },
  );

  test('Claude refusal surfaces as an error', () async {
    final sse =
        'data: ${jsonEncode({
          'type': 'message_delta',
          'delta': {'stop_reason': 'refusal'},
        })}\n\n';
    final client = AiClient(
      httpClient: MockClient.streaming(
        (_, _) async =>
            http.StreamedResponse(Stream.value(utf8.encode(sse)), 200),
      ),
    );

    await expectLater(
      client.generate(settings: _settings(AiProvider.anthropic), prompt: 'p'),
      throwsA(predicate((e) => e.toString().contains('declined'))),
    );
  });

  test('cancel aborts a pending request', () async {
    final token = AiCancelToken();
    final client = AiClient(
      httpClient: MockClient((_) => Completer<http.Response>().future),
    );

    final pending = client.generate(
      settings: _settings(AiProvider.openai),
      prompt: 'p',
      cancelToken: token,
    );
    token.cancel();

    await expectLater(pending, throwsA(isA<AiCancelledException>()));
  });

  test('retired Gemini models migrate to the current default', () {
    expect(migrateGeminiModel('gemini-1.5-flash'), defaultGeminiModel);
    expect(migrateGeminiModel('models/gemini-1.0-pro'), defaultGeminiModel);
    expect(migrateGeminiModel('gemini-2.5-pro'), 'gemini-2.5-pro');
  });
}
