import 'package:personal/features/home/analysis_data_preview.dart';

String buildAnalysisChecklistDomainEligibilityBlock(
  AnalysisSourceSelection selection,
) {
  final required = <String>[];
  if (selection.includes(AnalysisDataSourceId.health)) {
    required.add('Health & Sleep');
  }
  if (selection.includes(AnalysisDataSourceId.expenses)) {
    required.add('Expenses');
  }
  if (selection.includes(AnalysisDataSourceId.location)) {
    required.add('Location & Mobility');
  }
  if (selection.includes(AnalysisDataSourceId.gameActivity)) {
    required.add('Gaming & Leisure');
  }
  if (selection.includes(AnalysisDataSourceId.calendar)) {
    required.add('Calendar & Schedule');
  }

  if (required.isEmpty) {
    return 'No domain checklist subsections are required for this run.';
  }

  return 'Required checklist subsections for each week: ${required.join(', ')}.';
}

String buildAnalysisChecklistDomainSectionsBlock(
  AnalysisSourceSelection selection,
) {
  final sections = <String>[];

  if (selection.includes(AnalysisDataSourceId.health)) {
    sections.add('''
#### **Health & Sleep**

* [Actionable Directive]: [Exact sleep, hydration, or recovery target for this week only].'''
        .trimRight());
  }

  if (selection.includes(AnalysisDataSourceId.expenses)) {
    sections.add('''
#### **Expenses**

* [Actionable Directive]: [Exact spend cap, logging task, no-buy rule, or recovery action derived from observed spending].'''
        .trimRight());
  }

  if (selection.includes(AnalysisDataSourceId.location)) {
    sections.add('''
#### **Location & Mobility**

* [Actionable Directive]: [Punctuality or commute-timing target when late arrivals are the anomaly — e.g. departure buffer, target arrival time; omit motorcycle distance or weekly km targets unless mobility volume is flagged in Patterns & Anomalies].'''
        .trimRight());
  }

  if (selection.includes(AnalysisDataSourceId.gameActivity)) {
    sections.add('''
#### **Gaming & Leisure**

* [Actionable Directive]: [Exact wind-down routine, gaming limit, or screen-time restriction].'''
        .trimRight());
  }

  if (selection.includes(AnalysisDataSourceId.calendar)) {
    sections.add('''
#### **Calendar & Schedule**

* [Actionable Directive]: [Exact adjustment tied to workdays, events, holidays, or recovery scheduling].'''
        .trimRight());
  }

  return sections.join('\n\n');
}
