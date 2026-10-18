import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motohealth/features/ai/ai_client.dart';
import 'package:motohealth/features/ai/ai_settings.dart';
import 'package:motohealth/features/ai/bike_snapshot.dart';
import 'package:motohealth/features/ai/schedule_plan.dart';
import 'package:motohealth/features/garage/maintenance_catalog.dart';
import 'package:motohealth/features/garage/moto_models.dart';

const _plan = '''
Here is my choice:
```json
{
  "identified": "2021 Honda CB Shine SP 125, air-cooled, fuel injected, chain drive",
  "confidence": "medium",
  "assumptions": ["Indian market BS6 model"],
  "warnings": [],
  "selected": [
    {"id": "chain-lube", "reason": "Chain drive.", "confidence": "high"},
    {"id": "oil", "reason": "Every engine.", "confidence": "high"},
    {"id": "oil", "reason": "dup", "confidence": "low"},
    {"id": "valve-clearance", "reason": "Screw adjusters.", "confidence": "weird"},
    {"id": "made-up-job", "reason": "not in the catalog"},
    {"id": "throttle-body"}
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
    ServiceTask(id: 'brake-pads', name: 'Brake pads', intervalKm: 15000),
    ServiceTask(id: 'old-custom', name: 'My own job', intervalDays: 30),
  ],
);

void main() {
  group('parseSchedulePlan', () {
    test('keeps only catalog ids, in catalog order, without duplicates', () {
      final plan = parseSchedulePlan(_plan);
      expect(plan.identified, contains('CB Shine SP 125'));
      expect(plan.confidence, Confidence.medium);
      expect(plan.assumptions, ['Indian market BS6 model']);
      expect(plan.picks.map((p) => p.item.id), [
        'oil',
        'valve-clearance',
        'throttle-body',
        'chain-lube',
      ]);
      final oil = plan.picks.first;
      expect(oil.reason, 'Every engine.');
      expect(oil.confidence, Confidence.high);
      // Unknown or missing confidence is treated as the least trusted.
      expect(plan.picks[1].confidence, Confidence.low);
      expect(plan.picks[2].confidence, Confidence.low);
    });

    test('accepts bare id strings', () {
      final plan = parseSchedulePlan('{"selected": ["oil", "tyres"]}');
      expect(plan.picks.map((p) => p.item.id), ['oil', 'tyres']);
    });

    test('rejects answers with nothing usable', () {
      expect(() => parseSchedulePlan('sorry'), throwsFormatException);
      expect(
        () => parseSchedulePlan('{"selected": []}'),
        throwsFormatException,
      );
      expect(
        () => parseSchedulePlan('{"selected": [{"id": "nope"}]}'),
        throwsFormatException,
      );
      expect(
        () => parseSchedulePlan('{"selected": [1,'),
        throwsFormatException,
      );
    });
  });

  group('applySelection', () {
    test('adds chosen jobs from the catalog and keeps edited intervals', () {
      final tasks = applySelection(bike(), {'oil', 'coolant'}, replace: false);
      expect(tasks.firstWhere((t) => t.id == 'oil').intervalKm, 5000);
      final coolant = tasks.firstWhere((t) => t.id == 'coolant');
      expect(coolant.name, 'Coolant');
      expect(coolant.intervalDays, 730);
      expect(tasks.map((t) => t.id), containsAll(['tyres', 'old-custom']));
    });

    test('replace drops unchosen catalog jobs, not custom or with history', () {
      final tasks = applySelection(
        bike(),
        {'oil'},
        replace: true,
        withHistory: {'brake-pads'},
      );
      final ids = tasks.map((t) => t.id).toList();
      expect(ids, contains('oil'));
      expect(ids, contains('old-custom'));
      expect(ids, contains('brake-pads'));
      expect(ids, isNot(contains('tyres')));
    });
  });

  group('catalog', () {
    test('ids are unique and starter jobs exist', () {
      final ids = maintenanceCatalog.map((i) => i.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in starterJobIds) {
        expect(catalogItem(id), isNotNull, reason: id);
      }
    });

    test('every job has an interval and a hint', () {
      for (final i in maintenanceCatalog) {
        expect(i.km != null || i.days != null, isTrue, reason: i.id);
        expect(i.hint, isNotEmpty);
      }
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
    final prompt = buildSchedulePrompt(bike(), 4321);
    expect(prompt, contains('"make": "Honda"'));
    expect(prompt, contains('"model": "CB Shine"'));
    expect(prompt, contains('"current_odometer_km": 4321'));
    expect(prompt, contains('oil | Engine oil | applies to:'));
    expect(prompt, contains('coolant | Coolant | applies to: liquid-cooled'));
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
