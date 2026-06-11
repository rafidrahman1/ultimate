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

  static const rulesForAnalysis = '''
RULES FOR ANALYSIS:

1. Evidence Boundary (No Speculation)

Use only the provided data.

Do not invent:

* emotional state
* stress level
* addiction
* burnout
* medical conditions
* motivations
* intentions

unless explicitly supported by provided evidence.

If causality is weak, partial, or ambiguous, use uncertainty phrasing:

* may
* possibly
* insufficient evidence to confirm

If a domain is missing or excluded, acknowledge the gap explicitly and avoid fabricated analysis.

2. Deterministic Anomaly Prioritization

When DERIVED METRICS shows Month: Stable, report only data-supported anomalies (no padding to three severe items).

Otherwise, rank and report the top 3 highest-impact anomalies across all domains first.

Score anomalies using:

1. Severity
2. Recurrence
3. Cross-domain impact

Only after top 3 anomalies are reported, include secondary observations.

3. Cross-Domain Causality

Explicitly connect calendar events, holidays, travel, late-night routines, and lifestyle disruptions to measurable impacts on:

{{crossDomainImpacts}}

Only state causal links directly supported by timestamps, counts, or numeric deltas in the data.

4. Financial Contextualization

Use {{monthlyIncomeBdt}} BDT as the monthly baseline.

Calculate percentages for:

{{expenseCategories}}

For each financial anomaly report:

* absolute amount
* percentage of monthly income
* recurrence

Rank every expense category from DATA TO ANALYZE by percentage of monthly income (highest first). Include amount, percentage, and purchase count for each category in the Expense Category Ranking section.

Financial impact levels:

* Minor: >=0% and <3%
* Moderate: >=3% and <=10%
* Major: >10%

Resolve ties using:

1. Higher recurrence
2. Stronger cross-domain impact

5. Fatigue & Recovery Detection

Identify:

* rolling 7-day windows with 3+ short-sleep nights
* repeated post-02:00 bedtime clusters
* cumulative sleep debt
* early wake disruptions
* failed rebound after holidays, events, or travel

Highlight behavioral clusters rather than isolated incidents.

6. Goal Anchoring

Evaluate how anomalies affect:

* sleep regularity
* active recovery
* budget stability
* work structure
* long-term sustainability

7. Recommendation Constraints

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

8. Weekly Action Plan Generation

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

9. Progressive Target Escalation

Do not recommend more than a 30% week-over-week increase on any metric unless required by travel or special events.

Weekly targets must step up gradually from the observed baseline across the month.

10. Progressive Sleep Recovery

If repeated short-sleep clusters exist:

Week 1:
* bedtime consistency

Week 2:
* sleep duration improvement

Week 3:
* eliminate late-night drift

Week 4:
* stabilization

Week 5:
* sustain gains

Do not immediately prescribe perfect sleep schedules.

Adjust targets based on observed sleep behavior.

Example:

Observed bedtime:
02:00–03:00

Reasonable target:
01:00–01:30

Unreasonable target:
22:30

11. Financial Recovery Rules

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

12. Weekly Theme System

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

13. Adherence Score Optimization

Prefer actions that are likely to be completed.

Examples:

Prefer:
* bedtime before 01:00 achieved consistently

over:
* bedtime before 23:00 likely to fail

when historical behavior is substantially later.

Optimize for consistency rather than perfection.

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

Apply Rule 12 first: the weekly theme calibrates how hard each priority is pushed (targets, caps, recovery load).

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

Before generating the final report:

* Recalculate every count directly from the provided data.
* Verify:
  - anomaly counts
  - recurrence counts
  - percentages
  - category totals
  - workday counts
  - sleep cluster counts
  - late bedtime counts
  - short-sleep counts

If a calculated value differs from source data, recalculate before output.

Never estimate counts.
Never round counts unless explicitly requested.

17. Calendar Disruption Analysis

For every holiday, travel event, training event, or multi-day calendar block:

Evaluate:

* sleep duration before event
* sleep duration during event
* sleep duration after event
* spending behavior before event
* spending behavior during event
* spending behavior after event

Determine whether:

* disruption occurred
* recovery occurred
* recovery failed

Only report causal relationships directly supported by timestamps, counts, or numeric deltas.

If evidence is insufficient, explicitly state:

"Insufficient evidence to confirm event impact."

18. Recommendation Consistency

A recommendation may not assume facts that were previously marked uncertain.

If a conclusion contains:

* uncertain
* ambiguous
* insufficient evidence

then all downstream recommendations must preserve that uncertainty.

Do not impose corrective actions that require unsupported assumptions.

Example:

Allowed:
"Verify whether the purchase was discretionary before applying a cooling-off period."

Not allowed:
"Apply a cooling-off period immediately."

19. Domain Conditional Sections

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

20. Target Generation Rules

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

Do not derive weekly motorcycle km targets from monthly totals (e.g. monthly km × 0.75). Weekly mobility targets must match the actual anomaly — punctuality targets for late arrivals, not inflated distance quotas.''';

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

* {{checklistMonth}} Week Blocks:
{{checklistWeekBlocks}}''';

  static const outputFormat = '''
  OUTPUT FORMAT:

Generate the response strictly using the following Markdown structure.

Determinism rules:

* In **Patterns & Anomalies**, list top 3 anomalies first unless DERIVED METRICS shows Month: Stable.
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

List every expense category from DATA TO ANALYZE, sorted by percentage of monthly income (highest first):

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
* Assume Sun–Thu are primary work/productivity days.
* Use Fri–Sat for recovery, errands, mobility maintenance, and social obligations.
* Reduce intensity during post-holiday recovery weeks.
* Derive spending limits from observed behavior; explain calculations when relevant.
* Include only sections for domains present in DATA TO ANALYZE and not marked "Excluded from this analysis run".
* Do not output a domain header or recommendations for excluded or missing domains. Do not use placeholder text.
* Use a specific directive name in each bullet bold label (e.g. **Bedtime lock**, **Gaming cap**). Never use **Target** alone as the label.

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
}
