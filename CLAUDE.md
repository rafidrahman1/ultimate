# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Personal is a private Flutter app (Android-primary) that pulls together personal data from several
sources — health, spending, location, gaming, calendar — shows them on a dashboard with
predictions, and can export them to Markdown. All personal data stays on-device unless the user opts into a cloud AI provider (OpenAI,
Gemini, or Claude) in settings; Firebase (Auth + Firestore) is used only for Google sign-in and syncing the
personal-info profile (`firestore.rules` scopes each user to `users/{uid}/personalInfo`).

## Commands

```bash
flutter pub get                 # install deps
flutter run                     # run on connected device/emulator
flutter analyze                 # static analysis (flutter_lints, package:flutter_lints/flutter.yaml)
dart format .                   # format code
```

```bash
flutter test                    # unit + architecture tests under test/
```

Run `flutter analyze` and `flutter test` before calling work done; CI (`.github/workflows/ci.yml`) runs both plus a format check. Tests cover pure logic only (no UI/integration tests). `test/architecture_test.dart` fails if `core/` or `shared/` import feature code.

### Firebase setup (only needed if firebase_options.dart is missing)

Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart`, or run
`flutterfire configure --project=<project-id>`. This generates `lib/firebase_options.dart` and
`android/app/google-services.json`, neither of which is committed.

## Architecture

```
lib/
  app/          # MaterialApp shell + route table (app/router.dart)
  core/         # Cross-cutting infrastructure; must not import features (enforced by test)
    storage/      #   prefs, generic JSON file cache (JsonFileCache), data-folder settings and directory
    period/       #   AnalysisPeriod math and the selected month
    lifecycle/    #   app lifecycle host/service
    schedule/     #   weekday and time-range schedules
    app_info/     #   version/build info
    theme/        #   design tokens and ThemeData
  features/     # One folder per domain; most use data/ + analysis/ + ui/ subfolders
    analysis/       # Period-scoped data providers, source selection (AnalysisSourceSelection),
                    #   month picker; ui/ holds the data-source confirm dialog used by export
    auth/           # Google account / Firebase auth
    calendar/       # data/ (Google Calendar sync), analysis/ (prompt text), ui/
    dashboard/      # view/ (view-models, provider), ui/ (screen, charts), predictions/ (cards, list, chooser)
    expenses/       # data/ (Cashew CSV, Drive), analysis/ (insights, prompt text), ui/
    forecasts/      # life/ (life forecasts), fuel/, outlook/ (bills, budget, payday),
                    #   reminders/ (prediction notifications, calendar sync)
    game_activity/  # Gaming session CSV parsing
    health/         # data/ (Health Connect), analysis/ (sleep, vitals prompts), ui/
    home/           # Home grid and summary providers
    location/       # data/ (Timeline export), analysis/ (place + work-arrival stats), ui/
    prompts/        # Personal-profile config (PromptConfig) and its screen, Firestore sync
    results/        # ai/ (AiClient), pipeline/ (data snapshot + derived metrics used by dashboard/export)
    settings/       # General settings, AI provider settings
  shared/       # Shared widgets, navigation helpers
  shell/        # Main shell (bottom nav: Home / Predictions), drawer
```

Each `lib/features/<domain>` module is self-contained: a `*_service.dart` that loads/parses raw data
(CSV files, Health Connect, Google Calendar API), a `*_summary`/model type, and often a
`*_prompt_builder.dart` that renders that domain's data into prompt text. State is Riverpod
(`flutter_riverpod`) throughout — most modules expose an `AsyncNotifierProvider` or similar for their
summary data.

### Data flow

Each source's summary comes from its feature's Riverpod provider, scoped to the selected month by
`lib/features/analysis/analysis_view_providers.dart` (`AnalysisPeriod` from
`lib/core/period/analysis_period.dart`). The dashboard (`features/dashboard/view/`) and the data export
(`features/export/`) both build on `buildDataSnapshot`
(`lib/features/results/pipeline/analysis_snapshot_builder.dart`), which renders each source through its
`*_prompt_builder.dart` plus derived metrics. `lib/features/results/ai/ai_client.dart` (`AiClient`) is the
shared OpenAI / Gemini / Claude client (retries, cancel token) used by the optional AI refinements of
predictions (`forecasts/*/..._ai.dart`), place naming and export curation, per `AiSettings`
(`lib/features/settings/ai_settings_service.dart`; API keys live in `flutter_secure_storage`).
There is no monthly-insights analysis, checklist or progress review any more.

### Persistence model

- **On-device cache** (`lib/core/storage/json_file_cache.dart` is the generic store; each domain owns its codec in `*_cache.dart`, e.g. `expenses/data/expenses_cache.dart`): last-loaded summaries per domain, stored as
  JSON files under the app-support `data_cache/` directory (atomic temp-file + rename writes, decoded
  off the UI isolate), so the app doesn't need to reparse files/re-hit APIs on every launch. Entries
  written by older builds to `shared_preferences` are migrated to files on first read.
- **Small settings** use `shared_preferences` via `lib/core/storage/prefs.dart` (`safePrefs()`, which returns
  null when the platform channel is unavailable so callers fall back to in-memory state).
- **Android backup is disabled** (`android:allowBackup="false"`) so cached personal data and
  Keystore-encrypted API keys never go to Google Drive backups.
- **User-selected data folder** (`lib/core/storage/data_folder_settings_service.dart`): a SAF/directory URI
  (`dir_picker`) where exports and backups live; resolved by `lib/core/storage/data_folder_directory.dart`.
- **Cloud sync**: only the personal-info profile syncs to Firestore
  (`lib/features/prompts/personal_info_firestore_service.dart`), gated by Firebase Auth uid, per `firestore.rules`.
- Everything else (parsed CSVs, cached summaries) is local-only.

### Navigation

Routes are a flat string-keyed switch in `app/router.dart` (`AppRoutes`) — no named-route generics or
nested routers. `MainShell` (`shell/main_shell.dart`) hosts the two-tab bottom nav (Home / Predictions) plus the drawer (`shell/app_drawer.dart`) for secondary screens (Prompts, General Settings,
per-feature settings).
