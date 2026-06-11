import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:personal/features/results/ai_client.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

class _RetryingHttpClient extends http.BaseClient {
  _RetryingHttpClient(this.failuresBeforeSuccess);

  final int failuresBeforeSuccess;
  int attempts = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    if (attempts <= failuresBeforeSuccess) {
      throw const SocketException('Software caused connection abort');
    }

    final body = jsonEncode({
      'choices': [
        {
          'message': {'content': 'ok'},
        },
      ],
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('retries transient connection aborts', () async {
    final client = AiClient(
      httpClient: _RetryingHttpClient(2),
      maxAttempts: 4,
    );

    final output = await client.generate(
      settings: AiSettings.initial().copyWith(
        openAiApiKey: 'test-key',
      ),
      prompt: 'hello',
    );

    expect(output, 'ok');
  });

  test('maps background abort to a friendly message', () async {
    final client = AiClient(
      httpClient: _RetryingHttpClient(99),
      maxAttempts: 2,
    );

    expect(
      () => client.generate(
        settings: AiSettings.initial().copyWith(
          openAiApiKey: 'test-key',
        ),
        prompt: 'hello',
      ),
      throwsA(
        predicate(
          (Object error) =>
              error.toString().contains('app went to the background'),
        ),
      ),
    );
  });
}
