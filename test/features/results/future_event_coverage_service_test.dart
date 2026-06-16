import 'package:flutter_test/flutter_test.dart';
import 'package:personal/features/analysis/analysis_period.dart';
import 'package:personal/features/calendar/calendar_event.dart';
import 'package:personal/features/home/analysis_data_preview.dart';
import 'package:personal/features/prompts/prompt_config_service.dart';
import 'package:personal/features/results/future_event_coverage_service.dart';
import 'package:personal/features/settings/ai_settings_service.dart';

const _initialOutput = '''
### **Clear Next Actions (June 2026)**

##### **Week 2 · 2026-06-08 to 2026-06-14 · Theme: Stabilization**

#### **Calendar & Schedule**
* **Routine:** Maintain work blocks.
''';

const _fixedWeek = '''
##### **Week 2 · 2026-06-08 to 2026-06-14 · Theme: Recovery**

#### **Calendar & Schedule**
* **Family Visit:** Reduce evening commitments during the visit.
''';

void main() {
  test('ensureFutureEventCoverageInOutput regenerates missing weeks', () async {
    final period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));
    final upcoming = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Family Visit',
          start: DateTime(2026, 6, 8),
          end: DateTime(2026, 6, 10),
          allDay: true,
        ),
      ],
    );
    var calls = 0;

    final result = await ensureFutureEventCoverageInOutput(
      output: _initialOutput,
      period: period,
      calendarUpcoming: upcoming,
      selection: AnalysisSourceSelection.all(),
      config: PromptConfig.initial(),
      aiSettings: AiSettings.initial(),
      generate: ({
        required settings,
        required prompt,
        required systemInstruction,
      }) async {
        calls++;
        expect(prompt, contains('Family Visit'));
        return _fixedWeek;
      },
    );

    expect(calls, 1);
    expect(result, contains('Family Visit'));
  });

  test('ensureFutureEventCoverageInOutput skips when calendar excluded', () async {
    final period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));

    final result = await ensureFutureEventCoverageInOutput(
      output: _initialOutput,
      period: period,
      calendarUpcoming: const CalendarSummary(events: []),
      selection: AnalysisSourceSelection({
        AnalysisDataSourceId.health,
      }),
      config: PromptConfig.initial(),
      aiSettings: AiSettings.initial(),
      generate: ({
        required settings,
        required prompt,
        required systemInstruction,
      }) async {
        fail('should not regenerate');
      },
    );

    expect(result, _initialOutput);
  });

  test('ensureFutureEventCoverageInOutput throws after max rounds', () async {
    final period = AnalysisPeriod.forDataMonth(DateTime(2026, 5, 1));
    final upcoming = CalendarSummary(
      events: [
        CalendarEvent(
          title: 'Family Visit',
          start: DateTime(2026, 6, 8),
          end: DateTime(2026, 6, 10),
          allDay: true,
        ),
      ],
    );

    expect(
      () => ensureFutureEventCoverageInOutput(
        output: _initialOutput,
        period: period,
        calendarUpcoming: upcoming,
        selection: AnalysisSourceSelection.all(),
        config: PromptConfig.initial(),
        aiSettings: AiSettings.initial(),
        generate: ({
          required settings,
          required prompt,
          required systemInstruction,
        }) async {
          return '''
##### **Week 2 · 2026-06-08 to 2026-06-14 · Theme: Stabilization**

#### **Calendar & Schedule**
* **Routine:** Still missing event names.
''';
        },
      ),
      throwsA(isA<FutureEventCoverageFailure>()),
    );
  });
}
