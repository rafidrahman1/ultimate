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

Rank and report the top 3 highest-impact anomalies across all domains first.

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

8. Output Quality Rules

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

19. Recommendation Traceability

Every recommendation must include:

* triggering metric
* observed value
* threshold used
* action

Recommendations must be directly traceable to data.

Format:

Trigger:
Observed:
Threshold:
Action:

Do not provide recommendations that lack a measurable trigger.

20. Sleep Cluster Prioritization

Treat clusters as higher priority than isolated anomalies.

Cluster score:

severity × recurrence × duration

Examples:

* 6 consecutive short-sleep nights
  outranks
* 1 isolated very short night

Always report the highest scoring cluster first.

When multiple clusters exist, rank them by:

1. Severity
2. Recurrence
3. Cross-domain impact

21. Full Expense Breakdown

For every expense category:

Calculate:

* amount
* percentage of monthly income
* purchase count

Rank all categories by percentage of monthly income.

Report the top 5 categories by income impact even if they are not anomaly categories.

22. Target Generation Rules

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

23. Domain Coverage Verification

Before finalizing:

Verify that:

* every included domain was analyzed
* every excluded domain was omitted
* all calendar events were evaluated
* all expense categories were processed
* all recommendations are traceable to data
* all percentages are mathematically correct
* all anomaly counts match source data

Output only after all checks pass.

24. Cross-Domain Evidence Requirements

When linking domains together:

Allowed:

* holiday → sleep disruption
* travel → bedtime drift
* late sleep → work arrival delays
* event spending → budget impact

Only if supported by timestamps or numeric evidence.

Not allowed:

* emotional explanations
* motivation explanations
* stress explanations
* behavioral assumptions

unless explicitly present in the source data.

25. Recommendation Confidence Labels

Every recommendation must be assigned one of:

* High confidence
* Moderate confidence
* Low confidence

Confidence is determined by evidence strength.

High confidence:
Directly supported by repeated measurements.

Moderate confidence:
Supported by partial evidence.

Low confidence:
Weak evidence or limited observations.

26. Contradiction Prevention

Before final output:

Check for contradictions.

Examples:

Not allowed:

* "Insufficient evidence purchase was discretionary"
* later:
  "Apply electronics cooling-off period"

Not allowed:

* "No proven relationship"
* later:
  "Relationship caused outcome"

If contradiction exists, revise the recommendation.

27. Event Utilization Requirement

Every listed calendar event must be evaluated.

For each event determine:

* no measurable effect
* measurable effect
* insufficient evidence

Events may not be ignored.

28. Data-Dense Output Preference

Prefer:

* counts
* percentages
* recurrence rates
* frequencies
* deltas
* rankings

Avoid narrative explanations when numeric explanations are available.

29. Explicit Recovery Assessment

For every major anomaly cluster:

Evaluate:

* disruption start
* disruption peak
* recovery attempt
* recovery success/failure

If recovery cannot be observed:

"Insufficient evidence to assess recovery."

30. Self-Audit Before Final Output

Before generating the final answer, internally verify:

✓ anomaly counts correct
✓ percentages correct
✓ rankings correct
✓ recommendations traceable
✓ excluded domains omitted
✓ uncertainty preserved
✓ no contradictions
✓ all calendar events reviewed
✓ all calculations validated

Only generate output after all checks pass.''';

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
  {{calendar}}''';

  static const outputFormat = '''
  OUTPUT FORMAT:

Generate the response strictly using the following Markdown structure.

Determinism rules:

* In **Patterns & Anomalies**, list top 3 anomalies first (ranked by severity, recurrence, cross-domain impact).
* Keep each anomaly bullet to 2 concise sentences maximum.
* Prefer quantified claims (counts, percentages, ranges, deltas) over narrative wording.
* Do not fabricate anomaly bullets for domains explicitly excluded in the data block.

### **Patterns & Anomalies**

* **[Metric Name]:** [Observation with exact data]. [Impact with explicit confidence or uncertainty when evidence is partial].
* **[Metric Name]:** [Observation with exact data]. [Cross-domain implication tied to behavior, schedule, or spending].''';

  static const focusHeader = 'Focus instructions:';
}
