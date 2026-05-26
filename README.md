# Personal

A Flutter app for aggregating personal data sources — health, expenses, automatic motorcycle commute tracking, chat, and more — with a unified analysis workflow.

## Structure

```
lib/
  app/           # App entry, routing
  theme/         # Colors and Material theme
  widgets/       # Shared UI components
  features/      # Feature modules (home, health, …)
  shell/         # App chrome (drawer, etc.)
```

## Getting started

```bash
flutter pub get
flutter run
```

Requires Android with Health Connect for the health feature.

### Commute tracking (Android)

Automatic motorcycle commute logging uses activity recognition (`IN_VEHICLE` with high confidence) to start GPS, and `STILL` for 3 minutes to end a trip. Trips are stored locally in SQLite. Grant activity recognition, location, and background location permissions when prompted.
