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

Never evaluate product value, market price, or purchasing decisions unless explicitly requested.''';

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
