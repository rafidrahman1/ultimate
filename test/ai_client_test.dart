import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal/features/results/ai/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

AiSettings settings(
  AiProvider provider, {
  String openAiModel = 'gpt-4o',
  String anthropicModel = 'claude-opus-5-5',
}) => AiSettings(
  provider: provider,
  openAiApiKey: 'k',
  openAiModel: openAiModel,
  geminiApiKey: 'k',
  geminiModel: defaultGeminiModel,
  anthropicApiKey: 'k',
  anthropicModel: anthropicModel,
  enableApiCalls: true,
);

http.Response openAiReply(String text) => http.Response(
  jsonEncode({
    'choices': [
      {
        'message': {'content': text},
      },
    ],
  }),
  200,
);

String sse(List<Map<String, dynamic>> events) =>
    events.map((e) => 'data: ${jsonEncode(e)}\n\n').join();

Map<String, dynamic> textDelta(String text) => {
  'type': 'content_block_delta',
  'delta': {'type': 'text_delta', 'text': text},
};

void main() {
  test('retries a rate-limited request and returns the later answer', () async {
    var calls = 0;
    final client = AiClient(
      httpClient: MockClient((request) async {
        calls++;
        if (calls == 1) {
          return http.Response('{}', 429, headers: {'retry-after': '0'});
        }
        return openAiReply(' hello ');
      }),
    );
    final reply = await client.generate(
      settings: settings(AiProvider.openai),
      prompt: 'p',
    );
    expect(reply, 'hello');
    expect(calls, 2);
  });

  test('a bad API key fails at once with a hint', () async {
    var calls = 0;
    final client = AiClient(
      httpClient: MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'message': 'bad key'},
          }),
          401,
        );
      }),
    );
    await expectLater(
      client.generate(settings: settings(AiProvider.openai), prompt: 'p'),
      throwsA(
        isA<Exception>().having(
          (e) => '$e',
          'message',
          allOf(contains('bad key'), contains('Check the API key')),
        ),
      ),
    );
    expect(calls, 1);
  });

  test('gives up after maxAttempts on a server error', () async {
    var calls = 0;
    final client = AiClient(
      maxAttempts: 2,
      httpClient: MockClient((request) async {
        calls++;
        return http.Response('{}', 503, headers: {'retry-after': '0'});
      }),
    );
    await expectLater(
      client.generate(settings: settings(AiProvider.openai), prompt: 'p'),
      throwsException,
    );
    expect(calls, 2);
  });

  test('reasoning models are not sent a temperature', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = AiClient(
      httpClient: MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return openAiReply('ok');
      }),
    );
    await client.generate(
      settings: settings(AiProvider.openai, openAiModel: 'gpt-5-mini'),
      prompt: 'p',
    );
    await client.generate(
      settings: settings(AiProvider.openai),
      prompt: 'p',
      systemInstruction: 'sys',
    );
    expect(bodies[0].containsKey('temperature'), isFalse);
    expect(bodies[1]['temperature'], 0.4);
    expect((bodies[1]['messages'] as List).first, {
      'role': 'system',
      'content': 'sys',
    });
  });

  test('a 400 is retried once without the optional parameters', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = AiClient(
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        return body.containsKey('temperature')
            ? http.Response('{"error":{"message":"unsupported"}}', 400)
            : openAiReply('ok');
      }),
    );
    final reply = await client.generate(
      settings: settings(AiProvider.openai),
      prompt: 'p',
    );
    expect(reply, 'ok');
    expect(bodies, hasLength(2));
    expect(bodies[1].containsKey('temperature'), isFalse);
  });

  test('Claude stream: joins text deltas', () async {
    late Map<String, dynamic> body;
    late Map<String, String> headers;
    final client = AiClient(
      httpClient: MockClient.streaming((request, bodyStream) async {
        body =
            jsonDecode(await bodyStream.bytesToString())
                as Map<String, dynamic>;
        headers = request.headers;
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              sse([
                textDelta('Hel'),
                textDelta('lo'),
                {
                  'type': 'message_delta',
                  'delta': {'stop_reason': 'end_turn'},
                },
              ]),
            ),
          ),
          200,
        );
      }),
    );
    final reply = await client.generate(
      settings: settings(AiProvider.anthropic),
      prompt: 'p',
      systemInstruction: 'sys',
    );
    expect(reply, 'Hello');
    expect(body['stream'], isTrue);
    expect(body['system'], 'sys');
    expect(body['output_config'], {'effort': 'high'});
    expect(headers['x-api-key'], 'k');
  });

  test('Claude stream: older models get no effort or fallbacks', () async {
    late Map<String, dynamic> body;
    final client = AiClient(
      httpClient: MockClient.streaming((request, bodyStream) async {
        body =
            jsonDecode(await bodyStream.bytesToString())
                as Map<String, dynamic>;
        return http.StreamedResponse(
          Stream.value(utf8.encode(sse([textDelta('ok')]))),
          200,
        );
      }),
    );
    await client.generate(
      settings: settings(
        AiProvider.anthropic,
        anthropicModel: 'claude-3-haiku',
      ),
      prompt: 'p',
    );
    expect(body.containsKey('output_config'), isFalse);
    expect(body.containsKey('fallbacks'), isFalse);
  });

  test('Claude stream: a fallback block drops the declined text', () async {
    final client = AiClient(
      httpClient: MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              sse([
                textDelta('partial'),
                {
                  'type': 'content_block_start',
                  'content_block': {'type': 'fallback'},
                },
                textDelta('final'),
              ]),
            ),
          ),
          200,
        );
      }),
    );
    final reply = await client.generate(
      settings: settings(AiProvider.anthropic),
      prompt: 'p',
    );
    expect(reply, 'final');
  });

  test('Claude stream: refusal and truncation are reported', () async {
    AiClient endingWith(String stopReason) => AiClient(
      httpClient: MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.value(
            utf8.encode(
              sse([
                textDelta('x'),
                {
                  'type': 'message_delta',
                  'delta': {'stop_reason': stopReason},
                },
              ]),
            ),
          ),
          200,
        );
      }),
    );
    await expectLater(
      endingWith(
        'refusal',
      ).generate(settings: settings(AiProvider.anthropic), prompt: 'p'),
      throwsA(predicate((e) => '$e'.contains('declined'))),
    );
    await expectLater(
      endingWith(
        'max_tokens',
      ).generate(settings: settings(AiProvider.anthropic), prompt: 'p'),
      throwsA(predicate((e) => '$e'.contains('output limit'))),
    );
  });

  test('a cancelled token stops the request', () async {
    final token = AiCancelToken()..cancel();
    final client = AiClient(
      httpClient: MockClient((request) async => openAiReply('never')),
    );
    await expectLater(
      client.generate(
        settings: settings(AiProvider.openai),
        prompt: 'p',
        cancelToken: token,
      ),
      throwsA(isA<AiCancelledException>()),
    );
  });

  test('a missing key is reported before any request is made', () async {
    var calls = 0;
    final client = AiClient(
      maxAttempts: 1,
      httpClient: MockClient((request) async {
        calls++;
        return openAiReply('x');
      }),
    );
    await expectLater(
      client.generate(
        settings: settings(AiProvider.openai).copyWith(openAiApiKey: ' '),
        prompt: 'p',
      ),
      throwsA(predicate((e) => '$e'.contains('API key is missing'))),
    );
    expect(calls, 0);
  });
}
