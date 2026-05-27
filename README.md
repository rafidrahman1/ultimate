# Personal

A Flutter app for aggregating personal data sources — health, expenses, chat, and more — with a unified analysis workflow.

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
