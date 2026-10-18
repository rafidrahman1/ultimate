# MotoHealth

A private Flutter app (Android-primary) for tracking everything about your motorcycle.
Data stays on the phone: no account, no backend. The only network use is the optional AI features, which send a bike's records to the provider you choose (OpenAI, Gemini or Claude) with your own API key.

## What it does

| Tab | What you get |
| --- | --- |
| **Home** | A bike-health score, estimated odometer and monthly pace, what needs attention, what is coming up |
| **Fuel** | Log fill-ups; km/l (average, last, best), fuel cost per km, price history |
| **Service** | Countdown for each maintenance job (oil, chain, filters, brakes, tyres…) by km and/or days; tap to mark done; full service history |
| **Costs** | Fuel + service + other expenses (insurance, gear, parking, fines…): this month, last 6 months, breakdown, cost per km |
| **Papers** | Insurance, registration, pollution check, licence with expiry dates |

### AI

- **Maintenance plan.** After you add a bike, the AI builds its service schedule from the exact
  make, model, year, variant, engine size and how/where you ride. It looks up published
  schedules on the web (Claude and Gemini), returns per-job intervals in km and days with oil
  grade, source and a confidence rating, and you tick what to apply. Regenerate any time from
  the Garage schedule screen. It is a starting point: check Low-confidence jobs against the
  owner's manual.
- **Analysis.** Health check, fuel & mileage, costs, maintenance review, 12-month forecast, and
  free-form questions, all grounded in your logs. Reports are saved per bike.
- Set the provider, key and model in Garage → AI settings. Keys are kept in secure storage.

Plus: several bikes, editable maintenance intervals per bike (Garage), light/dark/auto theme,
and local notifications before papers expire or a job falls due.

### How the numbers work

- **Odometer.** Every fuel, service and odometer entry is a data point. Today's odometer is the
  latest value plus your recent pace (km/day over the last ~120 days). An odometer never runs
  backwards, so a lower value than an earlier entry is rejected.
- **Mileage.** Full-tank method: km between two full fill-ups divided by litres added since the
  first one (partial fills in between are included).
- **Maintenance.** A job is due when either its km or its days interval is reached. It counts
  from the last service that ticked the job, or from when the bike was added.
- **Health score.** 70% maintenance (due-soon counts half), 30% papers (when any are added).

## Develop

```bash
flutter pub get
flutter run
flutter analyze
dart format .
flutter test
```

Code layout and conventions are in `CLAUDE.md`.

## Origin

MotoHealth was split out of "Personal", a private life-analytics app, keeping only its
motorcycle functionality (odometer, fuel, service forecasts) and rebuilding it as a
standalone app. The `main` branch still holds Personal.
