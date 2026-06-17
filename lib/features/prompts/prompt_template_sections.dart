/// Fixed prompt sections — not user-editable in the Prompts screen.
abstract final class PromptTemplateSections {
  static const defaultCrossDomainImpacts = [
    'sleep duration',
    'bedtime drift',
    'recovery quality',
    'sleep regularity',
    'discretionary spending',
    'fuel usage',
    'workday consistency',
  ];

  static const internalAnalysisPipeline = '''
INTERNAL ANALYSIS PIPELINE

Before generating the report, execute these steps in order:

1. Validate source data.
2. Recalculate all derived metrics.
3. Calculate financial percentages.
4. Calculate anomaly scores.
5. Rank anomalies.
6. Evaluate event impacts.
7. Generate recommendations.
8. Verify recommendation consistency.
9. Generate final output.

Do not expose this pipeline in the final response.''';

  static const rulesForAnalysis = '''
RULES FOR ANALYSIS:

1. Evidence Policy

Use only the provided data.

Do not infer:

* emotional state
* mental state
* stress
* burnout
* addiction
* motivation
* intentions
* medical diagnoses

unless explicitly supported by provided evidence.

When evidence is incomplete or ambiguous, use:

* may
* possibly
* insufficient evidence to confirm

Recommendations may only rely on supported conclusions.

If a conclusion is uncertain, all downstream recommendations must preserve that uncertainty.

2. Anomaly Scoring

Calculate:

Anomaly Score =
(Severity × 5)
+ (Recurrence × 3)
+ (Cross-Domain Impact × 2)

Sort descending by score.

Tie-breakers:

1. Higher recurrence
2. Higher cross-domain impact
3. Larger numeric impact

Use this ranking to order all reported anomalies.

3. Deterministic Anomaly Prioritization

If DERIVED METRICS shows:

Month: Stable

Report only data-supported anomalies.

Otherwise:

Report all data-supported anomalies ranked by Anomaly Score (highest first).

Do not invent anomalies without supporting evidence.

Secondary observations may appear only after the ranked anomalies.

4. Cross-Domain Causality

Explicitly connect calendar events, holidays, travel, late-night routines, and lifestyle disruptions to measurable impacts on:

{{crossDomainImpacts}}

Only state causal links directly supported by timestamps, counts, or numeric deltas in the data.

5. Financial Contextualization

Use {{monthlyIncomeBdt}} BDT as the monthly baseline.

Calculate percentages for:

{{expenseCategories}}

For each financial anomaly report:

* absolute amount
* percentage of monthly income
* recurrence

Financial Impact Levels:

Minor:
>=0% and <3%

Moderate:
>=3% and <10%

Major:
>=10%

Behavioral Significance:

Low:
<3% of monthly income

Medium:
3%–8%

High:
8%–15%

Critical:
>=15%

If two categories have equal significance:

1. Higher recurrence ranks higher.
2. Greater cross-domain impact ranks higher.

6. Expense Category Ranking Rules

Sort all categories by share of total spending descending.

Display:

* amount
* percentage of total spending (category_total / total_spent × 100)
* purchase count

Income utilization and remaining income use monthly income as the denominator.
Never label income percentages as category share percentages.
Top category share must use the same spending denominator.

Percentages must be recalculated from source data.

7. Fatigue & Recovery Detection

Identify:

* rolling 7-day windows with 3+ short-sleep nights
* repeated post-02:00 bedtime clusters
* cumulative sleep debt
* early wake disruptions
* failed rebound after holidays, events, or travel

Highlight behavioral clusters rather than isolated incidents.

8. Goal Anchoring

Evaluate how anomalies affect:

* sleep regularity
* active recovery
* budget stability
* work structure
* long-term sustainability

9. Recommendation Constraints

Avoid generic advice.

Every recommendation must include:

* measurable target
* numeric threshold
* behavioral trigger

Prefer quantified observations over descriptive narration.

Avoid:

* filler
* motivational language
* vague productivity advice
* repetitive phrasing

10. Weekly Action Plan Generation

The objective is behavior change, not theoretical optimization.

Weekly plans must maximize completion probability.

Use actual observed behavior as the starting point.

Do not prescribe ideal values immediately if current behavior is substantially below them.

Every weekly target must be:

* realistic
* progressive
* measurable
* achievable

Recovery weeks should have lower targets than normal weeks.

11. Weekly Planning Framework

Default monthly progression:

Week 1:
Recovery

Week 2:
Stabilization

Week 3:
Improvement

Week 4:
Maintenance

Week 5:
Review

Target Progression Limits:

Sleep:
Maximum +30 minutes improvement per week.

Spending:
Maximum 20% reduction per week.

Punctuality:
Maximum reduction of one late arrival equivalent per week.

Gaming:
Maximum 20% reduction per week.

Targets must start from observed behavior.

Do not jump directly to ideal values.

12. Financial Recovery Rules

Weekly spending limits must be derived from actual spending behavior.

Explain calculations when relevant.

Do not invent arbitrary spending caps.

Prefer:

"Reduce discretionary spending by 20% from May average"

instead of:

"Cap spending at 5,000 BDT"

unless the calculation supports it.

Electronics purchases should trigger a cooling-off period only when:

* electronics spending exceeded 5% of monthly income, AND
* the purchase is discretionary (luxury upgrade, non-essential gadget, impulse gear)

Do not apply a cooling-off period when evidence supports a necessary purchase:

* work-required hardware (job title, employer, or transaction note/category/title ties purchase to profession)
* emergency replacement of a failed essential device (broken phone, laptop, or tool needed for work or daily function)
* explicitly non-discretionary repair or replacement with no reasonable cheaper alternative

When work necessity vs. luxury is ambiguous from the data, state uncertainty and recommend verification before imposing a cooling-off rule — do not treat all electronics spend as a behavioral anomaly.

Cooling-off period (discretionary electronics only):

* 30 days without additional discretionary electronics purchases

13. Weekly Theme System

Each week must have a primary theme.

Themes:

* Recovery
* Stabilization
* Improvement
* Maintenance
* Review

Assign exactly one theme to every week.

All recommendations for that week must support the theme.

The weekly theme sets intensity and emphasis — not the priority order in Rule 14.

Theme examples:

* Recovery: lower targets across all domains; Priority 1 (sleep/recovery) leads with reduced load on budget and mobility
* Stabilization: hold current baselines; emphasize consistency over expansion
* Improvement: allow stronger targets on lower-ranked priorities (e.g. budget caps, commute optimization) while keeping Priority 1 recommendations present but not maximally aggressive
* Maintenance: sustain recent gains with minimal net-new pressure
* Review: summarize progress and adjust next-week theme; avoid stacking new hard targets

14. Recommendation Ranking

Within each week, list and emphasize recommendations in this order:

Priority 1:
* Sleep
* Recovery

Priority 2:
* Budget stability

Priority 3:
* Work punctuality and commute timing

Priority 4:
* Leisure adjustments (only when gaming is included in DATA TO ANALYZE)

Do not prescribe motorcycle distance or weekly km targets unless mobility volume is explicitly flagged as an anomaly in Patterns & Anomalies. When the mobility anomaly is punctuality (late arrivals, delayed departures), focus on departure buffers, target arrival times, and sleep-to-departure linkage — not scaling monthly km into weekly quotas.

Priority 5:
* Schedule structure

This is a tie-break and presentation order — not a mandate that Priority 1 must dominate every themed week.

Apply Rule 13 first: the weekly theme calibrates how hard each priority is pushed (targets, caps, recovery load).

Then apply this ranking: when two recommendations compete for emphasis, favor the higher priority unless the week's theme explicitly de-emphasizes that domain (e.g. Review week may lead with budget or mobility summaries over new sleep prescriptions).

15. Output Quality Rules

Keep output:

* analytical
* concise
* data-dense
* metric-focused

Every recommendation must be traceable to data.

If evidence is insufficient:

state explicitly:

"Insufficient evidence to support stronger conclusion."

Never introduce new sections not requested by the output format.

Never use external knowledge.

Never evaluate product value, market price, or purchasing decisions unless explicitly requested.

16. Numeric Validation

Before final output:

* recalculate all counts
* recalculate all percentages
* recalculate all rankings
* verify anomaly counts
* verify recurrence counts
* verify sleep metrics
* verify workday metrics

Never estimate counts.

Use source data only.

17. Calendar Disruption Analysis

For every holiday, travel event, training event, or multi-day calendar block:

Evaluate:

* sleep duration before event
* sleep duration during event
* sleep duration after event
* spending behavior before event
* spending behavior during event
* spending behavior after event

Event Windows:

Before:
3 days before event

During:
event duration

After:
3 days after event

Only report impacts supported by measurable changes.

Determine whether:

* disruption occurred
* recovery occurred
* recovery failed

Only report causal relationships directly supported by timestamps, counts, or numeric deltas.

If evidence is insufficient, explicitly state:

"Insufficient evidence to confirm event impact."

18. Mobility Analysis

Sleep-Mobility Association Confidence:

Strong:
>=75% of late arrivals preceded by short sleep

Moderate:
50%–74%

Weak:
25%–49%

None:
<25%

Use the appropriate confidence label whenever sleep-arrival relationships are discussed.

19. Gaming Analysis Rules

Gaming is anomalous only if:

* play time exceeds 10 hours/week
  OR
* gaming overlaps documented sleep anomalies
  OR
* gaming occurs after 01:00

Otherwise treat gaming as informational only.

Do not create gaming recommendations unless one of the above conditions is met.

20. Domain Conditional Sections

Sections listed in the output template are conditional.

If a domain is excluded or missing in DATA TO ANALYZE (marked "Excluded from this analysis run" or absent):

* omit the section header entirely
* omit all recommendations for that domain
* do not output placeholder text

The domain must not appear anywhere in:

* anomaly analysis
* recommendations
* weekly plans
* targets
* summaries

Example:

Gaming excluded
→ Do not output "Gaming & Leisure" section.

21. Target Generation Rules

Every numeric target must be derived from observed data.

Show the calculation whenever a target is introduced.

Allowed:

Observed:
6h 30m average sleep

Target:
7h 00m

Reason:
+30 minute improvement

Not allowed:

Target:
8h sleep

Reason:
not derived from data

Do not invent arbitrary spending caps, sleep targets, commute targets, or activity targets.

Do not derive weekly motorcycle km targets from monthly totals (e.g. monthly km × 0.75). Weekly mobility targets must match the actual anomaly — punctuality targets for late arrivals, not inflated distance quotas.

22. Upcoming Schedule (Future Events)

When Calendar & Schedule includes a Future Events section:

* Use it only for forward-looking weekly checklist planning — not for Patterns & Anomalies, Event Analysis claims, or retrospective disruption.
* Map each future holiday, travel, training, wedding, or multi-day block to the exact checklist week segment from {{checklistMonth}} Week Blocks.
* For affected weeks: prefer Recovery or Stabilization themes; reduce sleep, spending, and mobility targets; add prep buffers or post-event recovery actions per Rules 10–13.
* Do not treat future events as if they already occurred. Do not invent events absent from the data.

23. Future Event Coverage Check

Before final output (when Future Events are present in Calendar & Schedule):

* Extract all Future Events.
* Map each event to its week block from {{checklistMonth}} Week Blocks.
* Verify every event appears by name in the corresponding week's #### **Calendar & Schedule** subsection.
* If any event is missing, regenerate the affected week.

Output must not omit any Future Event.''';

  static const calendarScheduleDataGuidance = '''
  Calendar block sections:
  - Calendar Events: events within the analysis period (with Event Analysis when present). Use for retrospective disruption and anomaly causality.
  - Future Events: synced events after the analysis period end. Planning context only — not evidence of past behavior.

  When generating weekly checklist targets: read Future Events first; match each event to the correct week segment; lower intensity and add prep/recovery for affected weeks. Do not report Future Events as completed disruptions.''';

  static const calendarScheduleDataGuidanceWeeklyVerify = '''
  Calendar block sections:
  - Calendar Events: events during this week (see Week data range above). Primary evidence for schedule-related verdicts.
  - Future Events: synced events after this week. Context only — do not use as proof of Met or Failed for this week.

  Use Future Events only when a checklist action explicitly targets upcoming schedule (prep, buffers before travel/holidays). Verdicts for past-tense targets must use Calendar Events and other week data only.''';

  static const derivedMetrics = '''
DERIVED METRICS:

{{derivedMetrics}}''';

  static const dataToAnalyze = '''
  DATA TO ANALYZE:

* Health ({{analysisMonth}}):
  {{health}}

* Expenses:
  {{expenses}}

* Location & Mobility:
  {{location}}

* Gaming & Screen Time:
  {{gameActivity}}

* Calendar & Schedule:
  {{calendar}}
''' +
      calendarScheduleDataGuidance +
      '''

* Goal Tracking:
  {{goalTracking}}

* {{checklistMonth}} Week Blocks:
{{checklistWeekBlocks}}''';

  static const outputFormat = '''
  OUTPUT FORMAT:

Generate the response strictly using the following Markdown structure.

Determinism rules:

* In **Patterns & Anomalies**, list all data-supported anomalies ranked by Anomaly Score (highest first). If DERIVED METRICS shows Month: Stable, report only clearly supported anomalies.
* Keep each anomaly bullet to 2 concise sentences maximum.
* Prefer quantified claims (counts, percentages, ranges, deltas) over narrative wording.
* Do not fabricate anomaly bullets for domains explicitly excluded in the data block.
* Every recommendation must be traceable to data.
* Assign exactly one weekly theme (Recovery, Stabilization, Improvement, Maintenance, or Review) per week segment.
* Apply progressive targets, weekly themes, and recommendation priority order from the analysis rules.

### **Patterns & Anomalies**

* **[Metric Name]:** [Observation with exact data]. [Impact with explicit confidence or uncertainty when evidence is partial].
* **[Metric Name]:** [Observation with exact data]. [Cross-domain implication tied to behavior, schedule, or spending].

### **Expense Category Ranking**

List every expense category from DATA TO ANALYZE, sorted by share of total spending (highest first):

* **[Category]:** [amount] BDT · [X.X]% of income · [N] purchases

Omit this section only if expenses are excluded from the run.

### **Clear Next Actions ({{checklistMonth}})**

The checklist must cover the **entire month** of {{checklistMonth}} as **{{checklistWeekCount}} weekly segments**.

Rules:

* Do not merge weeks.
* Do not skip partial weeks.
* Do not reorder week segments.
* Use the exact week ranges from the {{checklistMonth}} Week Blocks in DATA TO ANALYZE.
* Weekly targets must adapt to holidays, travel, and recovery load.
* When Future Events are present in Calendar & Schedule, map each to its week segment before assigning themes and targets (Rule 22).
* Before final output, run the Future Event Coverage Check (Rule 23): every Future Event must appear by name in that week's #### **Calendar & Schedule** subsection; regenerate any week that omits one.
* Assume Sun–Thu are primary work/productivity days.
* Use Fri–Sat for recovery, errands, mobility maintenance, and social obligations.
* Reduce intensity during post-holiday recovery weeks.
* Derive spending limits from observed behavior; explain calculations when relevant.
* Include only sections for domains present in DATA TO ANALYZE and not marked "Excluded from this analysis run".
* Do not output a domain header or recommendations for excluded or missing domains. Do not use placeholder text.

{{checklistWeekSegments}}

For **each** week listed above, output one ##### week header, then **only** the applicable #### subsections below — in priority order, with no gaps for omitted domains:

##### **Week [N] · [exact range from list] · [Theme: Recovery | Stabilization | Improvement | Maintenance | Review]**

{{checklistDomainEligibility}}

{{dynamicChecklistDomainSections}}''';

  static const focusHeader = 'Focus instructions:';

  static const rulesForProgressReview = '''
RULES FOR PROGRESS REVIEW:

1. Evidence Boundary (No Speculation)

Use only the provided checklist targets, checklist completion marks, and current-month data.

Do not invent emotional state, stress, addiction, burnout, medical conditions, motivations, or intentions unless explicitly supported by data.

If causality is weak, use uncertainty phrasing (may, possibly, insufficient evidence).

2. Comparison Method

For every checklist target you can match to data:

* restate the original target from the checklist
* cite the matching metric from {{analysisMonth}} data
* compute a numeric delta when possible (sleep hours, spend totals, km, session counts)
* assign a verdict: Improved, Partial, Unchanged, or Declined

Prioritize measured data over checklist checkmarks. Checkmarks are self-reported adherence only.

3. Domain Scoring

Score each domain present in the checklist on a 0–100 scale:

* 0–25: Declined or no measurable progress
* 26–50: Minimal or inconsistent progress
* 51–75: Partial progress toward targets
* 76–100: Target met or clearly exceeded

Explain each score in one sentence tied to numbers.

4. Financial Contextualization

Use {{monthlyIncomeBdt}} BDT as the monthly baseline when judging spending targets.

When Verified financial ratios are provided below, copy those percentages exactly.
Do not recompute "% of monthly income" — the app pre-validates those values.

Report absolute amounts, percentages of income, and whether spending moved toward or away from checklist caps.

5. Recommendation Constraints

Avoid generic praise or vague advice.

Every carry-forward recommendation must include a measurable target and reference the gap found in this review.

6. Output Quality

Keep output analytical, concise, and metric-focused.

If a checklist target cannot be verified from the data, state "Insufficient data to verify" rather than guessing.

7. Domain Exclusion (Hard Rule)

Consult Domain scoring eligibility below.

For any EXCLUDED domain:
* output the #### header and exactly one bullet: * **Domain excluded.**
* do NOT assign a numeric score, verdict, delta, or penalty
* do NOT infer progress from excluded data''';

  static const dataForProgressReview = '''
DATA FOR PROGRESS REVIEW:

* Checklist source: {{checklistSource}}
* Checklist target month: {{checklistMonth}}
* Checklist completion: {{checklistCompletionSummary}}

* Checklist targets (by week):
{{checklistTargets}}

* Current-month data ({{analysisMonth}}):

* Health:
  {{health}}

* Expenses:
  {{expenses}}

* Location & Mobility:
  {{location}}

* Gaming & Screen Time:
  {{gameActivity}}

* Calendar & Schedule:
  {{calendar}}
''' +
      calendarScheduleDataGuidance +
      '''

* Verified financial ratios (pre-computed — use exact values):
{{verifiedFinancialFacts}}

* Domain scoring eligibility:
{{domainScoringRules}}''';

  static const outputFormatProgressReview = '''
OUTPUT FORMAT:

Generate the response strictly using the following Markdown structure.

* Quantify improvement with numbers wherever possible.
* Do not fabricate metrics for excluded domains.
* Do not generate a new weekly checklist.

### **Overall Improvement**

* **Checklist adherence:** [X of Y actions marked complete — Z%]
* **Data-backed summary:** [2–3 sentences citing the strongest improvements and regressions with exact numbers]
* **Overall score:** [0–100 with one-line justification]

{{dynamicDomainOutputFormat}}

### **What Worked**

* **[Highlight]:** [Specific behavior or metric that improved, with numbers]

### **Gaps & Next Focus**

* **[Gap]:** [Measurable carry-forward target for the remaining gap]''';

  static const progressFocusDefault =
      'Compare the checklist targets for {{checklistMonth}} against {{analysisMonth}} data. '
      'Quantify how much progress was made on each target and produce domain scores.';

  static const rulesForWeeklyChecklistVerification = '''
RULES FOR WEEKLY CHECKLIST VERIFICATION:

1. Evidence Boundary (No Speculation)

Use only the provided checklist targets for this week and the data for {{weekRangeLabel}}.

Do not invent emotional state, stress, motivations, or medical conditions unless explicitly supported by data.

If causality is weak, use uncertainty phrasing.

2. Per-Item Verdict

For every checklist action listed for this week:

* restate the target
* cite the matching metric from the week's data when available
* assign exactly one verdict: Met, Failed, or Unverified

Verdict definitions:

* Met — data clearly shows the target was achieved for this week
* Failed — data clearly shows the target was not achieved for this week
* Unverified — insufficient data to prove Met or Failed (do not guess)

3. Financial Contextualization

Use {{monthlyIncomeBdt}} BDT as the monthly baseline when judging spending targets.

When Verified financial ratios are provided below, copy those percentages exactly.

4. Output Quality

Keep output analytical, concise, and metric-focused.

Output one numbered line per checklist action in the exact order listed.

5. Calendar Context (Future Events)

Calendar Events cover this week only. Future Events lists synced schedule after this week.

* Met/Failed verdicts must use data from {{weekRangeLabel}} only — not Future Events.
* Use Future Events only to interpret checklist actions that explicitly reference upcoming schedule (trip prep, pre-holiday buffers) or to explain Unverified when an action depends on events not yet occurred.
* Do not treat Future Events as evidence that a disruption already happened this week.''';

  static const dataForWeeklyChecklistVerification = '''
DATA FOR WEEKLY CHECKLIST VERIFICATION:

* Checklist source: {{checklistSource}}
* Target month: {{checklistMonth}}
* Week: {{weekHeader}}
* Week data range: {{weekRangeLabel}}

* Checklist actions for this week:
{{weekChecklistTargets}}

* Data for this week:

* Health:
  {{health}}

* Expenses:
  {{expenses}}

* Location & Mobility:
  {{location}}

* Gaming & Screen Time:
  {{gameActivity}}

* Calendar & Schedule:
  {{calendar}}
''' +
      calendarScheduleDataGuidanceWeeklyVerify +
      '''

* Verified financial ratios (pre-computed — use exact values):
{{verifiedFinancialFacts}}

* Domain scoring eligibility:
{{domainScoringRules}}''';

  static const outputFormatWeeklyChecklistVerification = '''
OUTPUT FORMAT:

Generate the response strictly using the following Markdown structure.

### **Weekly Checklist Verification**

##### {{weekHeader}}

For each checklist action below, output one numbered line in the same order:

1. **Action title** — **Verdict:** Met | Failed | Unverified
   - **Evidence:** [metric from data or "Insufficient data"]
   - **Rationale:** [one sentence tied to evidence]

Do not skip actions. Do not add extra sections.''';

  static const weeklyVerifyFocusDefault =
      'Verify each checklist action for {{weekHeader}} against data from {{weekRangeLabel}}. '
      'Mark Met when achieved, Failed when clearly not achieved, Unverified when data is insufficient. '
      'Use Future Events only for forward-looking schedule actions — not as proof of this week\'s outcomes.';
}
