import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motohealth/features/ai/ai_client.dart';
import 'package:motohealth/features/ai/ai_settings.dart';
import 'package:motohealth/features/ai/bike_snapshot.dart';
import 'package:motohealth/features/ai/schedule_plan.dart';
import 'package:motohealth/features/garage/moto_models.dart';

const _plan = '''
Here is the plan:
```json
{
  "identified": "2021 Honda CB Shine SP 125, air-cooled, fuel injected, chain drive",
  "confidence": "medium",
  "assumptions": ["Indian market BS6 model"],
  "warnings": [],
  "tasks": [
    {"name": "Engine oil", "interval_km": 3000, "interval_days": 180,
     "spec": "10W-30 JASO MB, 0.9 L", "why": "Oil breaks down.",
     "source": "owner's manual", "confidence": "high"},
    {"name": "engine OIL", "interval_km": 1, "confidence": "high"},
    {"name": "Valve clearance", "interval_km": 12000, "confidence": "weird"},
    {"name": "Nothing", "interval_km": 5, "interval_days": 2},
    {"name": "", "interval_km": 3000},
    {"name": "Chain lube", "interval_km": "500"}
  ]
}
```
''';

Bike bike() => Bike(
  id: 'b',
  name: 'Daily',
  make: 'Honda',
  model: 'CB Shine',
  year: 2021,
  addedOn: DateTime(2026, 1, 1),
  startOdometer: 1000,
  tasks: const [
    ServiceTask(id: 'oil', name: 'Engine oil', intervalKm: 5000),
    ServiceTask(id: 'tyres', name: 'Tyres', intervalKm: 20000),
    ServiceTask(id: 'old', name: 'Battery check', intervalDays: 365),
  ],
);

void main() {
  group('parseSchedulePlan', () {
    test('reads JSON wrapped in prose, drops bad and duplicate jobs', () {
      final plan = parseSchedulePlan(_plan);
      expect(plan.identified, contains('CB Shine SP 125'));
      expect(plan.confidence, Confidence.medium);
      expect(plan.assumptions, ['Indian market BS6 model']);
      expect(plan.tasks.map((t) => t.name), [
        'Engine oil',
        'Valve clearance',
        'Chain lube',
      ]);
      final oil = plan.tasks.first;
      expect(oil.intervalKm, 3000);
      expect(oil.intervalDays, 180);
      expect(oil.confidence, Confidence.high);
      expect(oil.note, contains('JASO MB'));
      // Unknown confidence is treated as the least trusted.
      expect(plan.tasks[1].confidence, Confidence.low);
      // Numbers given as strings are accepted.
      expect(plan.tasks[2].intervalKm, 500);
    });

    test('rejects answers with no usable plan', () {
      expect(() => parseSchedulePlan('sorry'), throwsFormatException);
      expect(() => parseSchedulePlan('{"tasks": []}'), throwsFormatException);
      expect(() => parseSchedulePlan('{"tasks": [1,'), throwsFormatException);
    });
  });

  group('applyPlan', () {
    final chosen = parseSchedulePlan(_plan).tasks;

    test('keeps ids of jobs matched by name and adds new ones', () {
      final tasks = applyPlan(bike(), chosen, replace: false);
      final oil = tasks.firstWhere((t) => t.name == 'Engine oil');
      expect(oil.id, 'oil');
      expect(oil.intervalKm, 3000);
      expect(oil.intervalDays, 180);
      expect(tasks.map((t) => t.id), containsAll(['tyres', 'old']));
      expect(tasks.where((t) => t.id.startsWith('ai-')), hasLength(2));
    });

    test('replace drops unlisted jobs unless they have history', () {
      final tasks = applyPlan(
        bike(),
        chosen,
        replace: true,
        withHistory: {'tyres'},
      );
      expect(tasks.map((t) => t.id), contains('tyres'));
      expect(tasks.map((t) => t.id), isNot(contains('old')));
    });
  });

  test('missingBikeDetails names what the plan needs', () {
    final b = Bike(
      id: 'x',
      name: 'n',
      addedOn: DateTime(2026),
      startOdometer: 0,
      tasks: const [],
      make: 'Honda',
    );
    expect(missingBikeDetails(b), ['model', 'year']);
    expect(missingBikeDetails(bike()), isEmpty);
  });

  test('schedule prompt carries the exact bike and current odometer', () {
    final prompt = buildSchedulePrompt(bike(), 4321, ['Engine oil']);
    expect(prompt, contains('"make": "Honda"'));
    expect(prompt, contains('"model": "CB Shine"'));
    expect(prompt, contains('"current_odometer_km": 4321'));
    expect(prompt, contains('- Engine oil'));
  });

  test('snapshot lists mileage, due jobs and papers', () {
    final b = bike();
    final data = MotoData(
      bikes: [b],
      fuel: [
        FuelEntry(
          id: '1',
          bikeId: 'b',
          date: DateTime(2026, 1, 5),
          odometer: 1000,
          litres: 10,
          cost: 1000,
        ),
        FuelEntry(
          id: '2',
          bikeId: 'b',
          date: DateTime(2026, 1, 15),
          odometer: 1400,
          litres: 8,
          cost: 800,
        ),
      ],
      papers: [
        Paper(
          id: 'p',
          bikeId: 'b',
          type: PaperType.insurance,
          expiry: DateTime(2026, 2, 1),
        ),
      ],
    );
    final text = buildBikeSnapshot(data, b, DateTime(2026, 1, 20));
    expect(text, contains('2021 Honda CB Shine'));
    expect(text, contains('50.0 km/l'));
    expect(text, contains('Engine oil'));
    expect(text, contains('Insurance: expires 2026-02-01 (in 12 days)'));
  });

  group('AiClient', () {
    const settings = AiSettings(
      provider: AiProvider.anthropic,
      keys: {AiProvider.anthropic: 'k', AiProvider.gemini: 'g'},
    );

    test(
      'reads text blocks from a Claude answer, ignoring tool blocks',
      () async {
        final client = AiClient(
          httpClient: MockClient((req) async {
            expect(req.headers['x-api-key'], 'k');
            final body = jsonDecode(req.body) as Map;
            expect(body['tools'], isNotNull);
            return http.Response(
              jsonEncode({
                'content': [
                  {'type': 'server_tool_use', 'name': 'web_search'},
                  {'type': 'text', 'text': '{"ok": true}'},
                ],
              }),
              200,
            );
          }),
        );
        expect(
          await client.generate(
            settings: settings,
            prompt: 'x',
            webSearch: true,
          ),
          '{"ok": true}',
        );
      },
    );

    test(
      'retries without web search when the model rejects the tool',
      () async {
        var calls = 0;
        final client = AiClient(
          httpClient: MockClient((req) async {
            calls++;
            final hasTools = (jsonDecode(req.body) as Map).containsKey('tools');
            if (hasTools) {
              return http.Response(
                jsonEncode({
                  'error': {'message': 'tool not supported'},
                }),
                400,
              );
            }
            return http.Response(
              jsonEncode({
                'content': [
                  {'type': 'text', 'text': 'fine'},
                ],
              }),
              200,
            );
          }),
        );
        expect(
          await client.generate(
            settings: settings,
            prompt: 'x',
            webSearch: true,
          ),
          'fine',
        );
        expect(calls, 2);
      },
    );

    test('reads Gemini candidates', () async {
      final client = AiClient(
        httpClient: MockClient((req) async {
          expect(req.headers['x-goog-api-key'], 'g');
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'hello'},
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      expect(
        await client.generate(
          settings: settings.copyWith(provider: AiProvider.gemini),
          prompt: 'x',
        ),
        'hello',
      );
    });

    test('auth errors fail at once with a hint', () async {
      var calls = 0;
      final client = AiClient(
        httpClient: MockClient((req) async {
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
        client.generate(settings: settings, prompt: 'x'),
        throwsA(predicate((e) => e.toString().contains('Check the API key'))),
      );
      expect(calls, 1);
    });

    test('refuses to run without a key', () async {
      await expectLater(
        const AiClient().generate(settings: const AiSettings(), prompt: 'x'),
        throwsException,
      );
    });
  });
}
