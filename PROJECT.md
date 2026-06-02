# Personal — Project overview

A Flutter app that pulls together personal data from several sources—health, spending, location, gaming, and calendar—and runs a unified **monthly analysis** workflow. You pick which sources to include, configure how the AI should reason about your life, and get structured insights plus weekly checklists for the month ahead.

**Version:** 2.0.1  
**Platform:** Android (primary)

---

## What it does

Personal acts as a private **data hub**. Each feature module loads and summarizes one domain. From the home screen you can open any module or run **Run analysis**, which builds a prompt from your selected sources and either calls an external AI API (OpenAI or Gemini) or generates insights locally.

Analysis is scoped to the **current calendar month through today**. Parsed action items become **weekly checklists** for the following month, with optional local notifications when the month ends.

---

## Screenshots

Add images under `docs/screenshots/` and replace the placeholder paths below.

### Home — Data hub

<!-- Screenshot: Home grid (Health, Expenses, Location, Game Activity, Calendar, Results) and Run analysis button -->

<br><br>

![Home — Data hub](docs/screenshots/01-home.png)

<br><br>

---

### Health

<!-- Screenshot: Monthly steps/sleep summary from Health Connect -->

<br><br>

![Health — Monthly summary](docs/screenshots/02-health.png)

<br><br>

---

### Expenses

<!-- Screenshot: Cashew CSV import and spending summary -->

<br><br>

![Expenses — Summary](docs/screenshots/03-expenses.png)

<br><br>

---

### Location

<!-- Screenshot: Timeline / activity view from exported location data -->

<br><br>

![Location — Timeline](docs/screenshots/04-location.png)

<br><br>

---

### Game activity

<!-- Screenshot: Gaming sessions parsed from CSV export -->

<br><br>

![Game activity — Sessions](docs/screenshots/05-game-activity.png)

<br><br>

---

### Calendar

<!-- Screenshot: Google Calendar events for the analysis period -->

<br><br>

![Calendar — Events](docs/screenshots/06-calendar.png)

<br><br>

---

### Run analysis

<!-- Screenshot: Source selection dialog before running analysis -->

<br><br>

![Analysis — Source selection](docs/screenshots/07-analysis-confirm.png)

<br><br>

---

### Results & insights

<!-- Screenshot: Results list or insight report with parsed actions -->

<br><br>

![Results — Insights](docs/screenshots/08-results.png)

<br><br>

---

### Weekly checklists

<!-- Screenshot: Checklist broken down by week for the target month -->

<br><br>

![Checklists — Weekly view](docs/screenshots/09-checklists.png)

<br><br>

---

### Prompts & AI settings

<!-- Screenshot: Prompt template / assistant identity configuration -->

<br><br>

![Prompts — Configuration](docs/screenshots/10-prompts.png)

<br><br>

---

## Features

| Module | Data source | Role in analysis |
|--------|-------------|------------------|
| **Health** | Health Connect (steps, sleep) | Monthly averages, daily breakdowns, anomaly filtering |
| **Expenses** | Cashew CSV export folder | Totals, categories, real vs. excluded transactions |
| **Location** | User-selected timeline export files | Activity patterns for the analysis month |
| **Game activity** | CSV export (e.g. gaming tracker) | Session summaries |
| **Calendar** | Google Calendar (OAuth) | Events merged into the analysis snapshot |
| **Results** | Generated locally or via API | Stored runs, rich-text reports, actionable checklists |

Supporting screens (drawer): **Prompts** (system instructions and focus), **General settings** (analysis month, AI provider, notifications), and per-feature **settings** (folders, permissions, Google sign-in).

---

## Architecture

```
lib/
  app/              # App shell and route table
  core/             # Analysis period, caching, notifications
  features/         # health, expenses, location, game_activity, calendar, results, prompts, home, settings
  shell/            # Drawer navigation
  theme/            # Colors, light/dark theme
  widgets/          # Shared UI (tiles, metrics, pinned summaries)
```

- **State:** [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)
- **Health:** [health](https://pub.dev/packages/health) + Health Connect on device
- **Files:** [file_picker](https://pub.dev/packages/file_picker), [dir_picker](https://pub.dev/packages/dir_picker), [uri_content](https://pub.dev/packages/uri_content)
- **Calendar:** [google_sign_in](https://pub.dev/packages/google_sign_in) + [googleapis](https://pub.dev/packages/googleapis)
- **Notifications:** [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) (month-end analysis reminder)

---

## Getting started

### Prerequisites

- Flutter SDK (Dart ^3.11)
- Android device or emulator
- For health: **Health Connect** installed; grant Steps and Sleep (e.g. via Samsung Health → Health Connect)
- For expenses: **Cashew** export folder on device storage
- For calendar: Google account with Calendar API access
- Optional: API keys for OpenAI or Gemini in general settings

### Run

```bash
flutter pub get
flutter run
```

### Tests

```bash
flutter test
```

---

## Privacy & data

All personal data stays on the device unless you enable **API calls** for analysis. Cached summaries are stored locally via `shared_preferences` and the data cache service. Google sign-in is used only for calendar sync when you connect an account.

---

## Screenshot checklist

| File | Screen |
|------|--------|
| `docs/screenshots/01-home.png` | Home / Data hub |
| `docs/screenshots/02-health.png` | Health summary |
| `docs/screenshots/03-expenses.png` | Expenses |
| `docs/screenshots/04-location.png` | Location |
| `docs/screenshots/05-game-activity.png` | Game activity |
| `docs/screenshots/06-calendar.png` | Calendar |
| `docs/screenshots/07-analysis-confirm.png` | Analysis source picker |
| `docs/screenshots/08-results.png` | Results / insight detail |
| `docs/screenshots/09-checklists.png` | Weekly checklists |
| `docs/screenshots/10-prompts.png` | Prompts configuration |

---

## License

Private project — not published to pub.dev (`publish_to: 'none'`).
