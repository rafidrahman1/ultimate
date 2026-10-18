import 'package:flutter/material.dart';

/// The analyses the AI can run over a bike's records.
enum AnalysisKind {
  health(
    'Health check',
    'Overall verdict and what to do first',
    Icons.monitor_heart_outlined,
    '''
Give a health check of this motorcycle.
## Verdict
Two or three sentences: overall condition of upkeep, with a score out of 10 and why.
## Do first
The most urgent actions, most important first, each with the reason and a rough cost if the records allow.
## Watch
Things that are fine today but will need attention within the next 3 months at the current riding pace.
## Gaps in the records
What is missing or looks wrong in the logs (e.g. no service ever logged, long gaps, odd odometer jumps).''',
  ),
  fuel(
    'Fuel & mileage',
    'Trends, anomalies, what changed',
    Icons.local_gas_station_outlined,
    '''
Analyse fuel use and mileage.
## Summary
Average, best and recent km/l and what they say, compared with what is normal for this model if you know it.
## Trend
Is mileage improving, steady or falling? Over what period?
## Anomalies
Any tank that stands out, with the likely causes (riding style, tyre pressure, chain, air filter, fuel quality, short trips). Only say what the numbers support.
## Money
Fuel cost per km, price per litre movement, and a projection of next month's fuel spend at the current pace.
## Tips
Three specific, practical actions for this bike.''',
  ),
  costs(
    'Costs',
    'Where the money goes and what is coming',
    Icons.payments_outlined,
    '''
Analyse what this motorcycle costs to run.
## Where it goes
Breakdown by category with shares, and cost per km.
## Unusual
Months or entries far above normal, and why they might have happened.
## Next 3 months
A forecast of spend, listing the known drivers: services due, document renewals, fuel at the current pace. Give a range, not a single number.
## Saving
Specific ways to cut cost without risking safety.''',
  ),
  maintenance(
    'Maintenance review',
    'Is the schedule right for this bike?',
    Icons.build_circle_outlined,
    '''
Review the maintenance for this motorcycle.
## Priorities
Every overdue or soon job in the order to do it, with why that order and a note on what happens if it is delayed.
## Schedule check
Compare the intervals in the app with what the manufacturer publishes for this exact model. List each job whose interval looks wrong and what it should be. If you are not sure of the manufacturer figure, say so.
## At this mileage
Parts and checks that commonly need attention on this model around its current odometer reading (tyres, chain and sprockets, brake pads, fork seals, battery, cables). Mark which are model-specific facts and which are general.
## Missing jobs
Jobs that are not in the list but should be.''',
  ),
  forecast(
    'Forecast',
    'Service dates, milestones, yearly km',
    Icons.query_stats_rounded,
    '''
Forecast the next 12 months for this motorcycle.
## Riding
Expected km per month and per year at the current pace, and the odometer on key dates.
## Calendar
A dated list of when each maintenance job and each document renewal falls due, soonest first. Use the pace to convert km intervals to dates, and say which assumption you used.
## Cluster days
Dates where several things fall due together and could be done in one visit.
## Budget
Estimated spend per quarter for service and renewals.''',
  ),
  ask(
    'Ask anything',
    'Your own question about this bike',
    Icons.chat_bubble_outline_rounded,
    '''
Answer the rider's question about this motorcycle. Use the records where they matter and say plainly when they do not cover it.''',
  );

  const AnalysisKind(this.title, this.subtitle, this.icon, this.instructions);

  final String title;
  final String subtitle;
  final IconData icon;
  final String instructions;
}

const analysisSystemPrompt = '''
You are an experienced motorcycle mechanic and analyst helping the owner of one bike. You are given the bike's records.

Rules:
- Base every statement about the bike on the records. Do not invent entries, readings or costs. When the records are thin, say so instead of guessing.
- Separate facts from the records, general knowledge about this model, and your own estimate. Label estimates as estimates.
- Be specific: name the job, the number, the date. No filler or generic safety lectures.
- For anything safety-critical (brakes, tyres, steering, chain), say it clearly and early.
- Never state a manufacturer specification you are not sure of. Say "check the owner's manual" for those.
- Format: markdown with "## " headings, "- " bullets and **bold** only. Keep it under 450 words unless asked for more.
''';

String buildAnalysisPrompt(
  AnalysisKind kind,
  String snapshot, {
  String? question,
}) {
  return '''
${kind.instructions}
${question == null || question.trim().isEmpty ? '' : '\nRider\'s question: ${question.trim()}\n'}
--- RECORDS ---
$snapshot''';
}
