# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal is a private Flutter app (Android-primary) that pulls together personal data from several
sources — health, spending, location, gaming, calendar — and runs AI analysis over them to produce
monthly insights and weekly checklists, then scores progress against those checklists the following
month. All personal data stays on-device unless the user opts into a cloud AI provider (OpenAI or
Gemini) in settings; Firebase (Auth + Firestore) is used only for Google sign-in and syncing the
personal-info profile (`firestore.rules` scopes each user to `users/{uid}/personalInfo`).

## Commands

```bash
flutter pub get                 # install deps
flutter run                     # run on connected device/emulator
flutter test                    # run all tests
flutter test test/features/results/insights_parser_test.dart   # run a single test file
flutter test --plain-name "some test description"              # run tests matching a name
flutter analyze                 # static analysis (flutter_lints, package:flutter_lints/flutter.yaml)
dart format .                   # format code
```

There is no CI config in this repo; `flutter analyze` and `flutter test` are the checks to run before
calling work done.

### Firebase setup (only needed if firebase_options.dart is missing)

Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart`, or run
`flutterfire configure --project=<project-id>`. This generates `lib/firebase_options.dart` and
`android/app/google-services.json`, neither of which is committed.

## Architecture

```
lib/
  app/          # MaterialApp shell + route table (app/router.dart)
  core/         # Period ranges, on-device data cache, folder settings, notifications, theme
  features/
    analysis/       # Analysis "kind" enum, period math, launch flow, saved-report storage
    auth/            # Google account / Firebase auth
    calendar/        # Google Calendar sync + prompt text builder
    expenses/        # Cashew CSV parsing + prompt text builder
    game_activity/   # Gaming session CSV parsing
    health/          # Health Connect data + sleep metrics
    home/            # Home grid, analyze/confirm dialogs (entry point for launching analysis)
    location/        # Timeline export parsing, work-arrival stats
    progress_review/ # Checklist-vs-actual scoring dashboard
    prompts/         # System prompt template + personal-profile config (source of truth for prompt text)
    results/         # AI client, prompt assembly, response parsing, checklist/report storage
    settings/        # General settings, AI provider settings
  shared/       # Shared widgets, navigation helpers
  shell/        # Main shell (bottom nav: Home / Checklist / Review), drawer
```

Each `features/<domain>` module is self-contained: a `*_service.dart` that loads/parses raw data
(CSV files, Health Connect, Google Calendar API), a `*_summary`/model type, and often a
`*_prompt_builder.dart` that renders that domain's data into prompt text. State is Riverpod
(`flutter_riverpod`) throughout — most modules expose an `AsyncNotifierProvider` or similar for their
summary data.

### The analysis pipeline (the core flow, spans many files)

This is the part that requires reading multiple files to understand, centered on
`lib/features/results/analysis_service.dart` (`AnalysisRunController`, provider: `analysisRunProvider`):

1. **Entry point:** `lib/features/analysis/analysis_launcher.dart` — `launchMonthlyInsightsAnalysis` /
   `launchProgressReviewAnalysis`, called from Home. These gate on having a data folder
   (`data_folder_settings_service.dart`) and a complete personal profile
   (`prompts/prompt_config_service.dart`) before proceeding.
2. **Period math:** `lib/features/analysis/analysis_period.dart` — analysis is always scoped to the
   *current calendar month through today*; the resulting checklist targets the *following* month,
   split into weekly segments (`checklistWeeks`).
3. **Data gathering:** each selected source (`AnalysisSourceSelection` in `analysis_kind.dart`) is read
   from its feature's Riverpod provider (already loaded/cached — analysis does not re-fetch from disk).
   Sources can be individually included/excluded per run.
4. **Snapshot + prompt assembly:** `_buildDataSnapshot` in `analysis_service.dart` turns each source's
   summary into a text block via that feature's `*_prompt_builder.dart` (e.g.
   `expense_prompt_builder.dart`, `sleep_prompt_builder.dart`, `mobility_prompt_builder.dart`,
   `calendar_prompt_builder.dart`) plus derived metrics (`derived_metrics_builder.dart`) and goal
   tracking (`goal_tracking_builder.dart`). These blocks are substituted into a template from
   `prompts/prompt_config_service.dart` / `prompt_template_sections.dart` (the user-editable system
   prompt + rules, configured in the Prompts screen).
5. **Generation:** `results/ai_client.dart` (`AiClient`) posts the assembled prompt + system
   instruction to OpenAI or Gemini per `AiSettings` (`settings/ai_settings_service.dart`), with retry/
   backoff for transient network errors. If "enable API calls" is off, a local heuristic generator
   (`_generateInsights` / `_generateProgressReview` in `analysis_service.dart`) produces a structured
   fallback report instead of calling out to an API — this local path must stay in sync with whatever
   the parser (`insights_parser.dart`) expects to find.
6. **Parsing + persistence:** raw model output is parsed by `results/insights_parser.dart`
   (`InsightsReportParser`) into structured insights + checklist actions, saved via
   `analysis_reports_storage.dart` / `results_service.dart`, and (for monthly insights with checklist
   actions) auto-selected as the active checklist source
   (`selected_checklist_result_service.dart`).
7. **Progress review** re-runs the same snapshot/prompt machinery against a *previous* monthly-insights
   result's checklist, adding `progress_review/progress_review_evaluation.dart`
   (`ProgressReviewEvaluationEngine`) which computes verified numeric deltas (e.g. real financial
   ratios) so the AI's/local scoring can't contradict the actual data — `enforce()` is applied to
   whatever text comes back.
8. **Weekly verification** (`verifyWeeklyChecklist`) does a smaller version of the same pipeline scoped
   to a single checklist week, updating per-item completion state via
   `insight_checklist_service.dart`.

Because nearly every step threads through `AnalysisSourceSelection`, adding a new data source means
touching: `analysis_kind.dart` (register the source id), a new `features/<domain>` module with a
prompt builder, and the corresponding branches in `_buildDataSnapshot`/`_renderPrompt` in
`analysis_service.dart`.

### Persistence model

- **On-device cache** (`core/data_cache_service.dart`): last-loaded summaries per domain, stored via
  `shared_preferences`, so the app doesn't need to reparse files/re-hit APIs on every launch.
- **User-selected data folder** (`core/data_folder_settings_service.dart`): a SAF/directory URI
  (`dir_picker`) where analysis reports and some exports live; required before any analysis can run.
- **Cloud sync**: only the personal-info profile syncs to Firestore
  (`prompts/personal_info_firestore_service.dart`), gated by Firebase Auth uid, per `firestore.rules`.
- Everything else (parsed CSVs, analysis results, checklists) is local-only.

### Navigation

Routes are a flat string-keyed switch in `app/router.dart` (`AppRoutes`) — no named-route generics or
nested routers. `MainShell` (`shell/main_shell.dart`) hosts the three-tab bottom nav (Home / Checklist /
Review) plus the drawer (`shell/app_drawer.dart`) for secondary screens (Prompts, General Settings,
per-feature settings).
