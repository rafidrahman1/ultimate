/// Fixed prompt sections — not user-editable in the Prompts screen.
abstract final class PromptTemplateSections {
  static const rulesForAnalysis = '''
RULES FOR ANALYSIS:

1. Evidence Boundary (No Speculation):
   Use only the provided data. Do not invent events, metrics, or causes.

Do not infer:

* emotional state
* stress level
* addiction
* burnout
* medical conditions

unless explicitly supported by provided evidence.

If causality is weak, partial, or ambiguous, use uncertainty phrasing ("may", "possibly", "insufficient evidence to confirm").

If a domain is missing or excluded, acknowledge the gap explicitly and avoid fabricated analysis for that domain.

2. Deterministic Anomaly Prioritization:
   Rank and report the top 3 highest-impact anomalies across all domains first.

Score anomalies using this order:

* severity
* recurrence
* cross-domain impact

Only after top 3 are reported, include secondary observations.

3. Cross-Domain Causality:
   Explicitly connect calendar events, holidays, travel, late-night routines, and lifestyle disruptions to measurable impacts on:

* sleep duration
* bedtime drift
* recovery quality
* step averages
* discretionary spending
* fuel usage
* workday consistency

Only state causal links directly supported by timestamps, counts, or numeric deltas in the provided data.

4. Financial Contextualization:
   Use {{monthlyIncomeBdt}} BDT as the financial baseline.

Calculate percentages for:

* discretionary spending
* electronics purchases
* gifts
* restaurant spikes
* fuel patterns

For each financial anomaly, report:

* absolute amount
* percentage of monthly income
* frequency/recurrence

Classify financial impact:

* Minor: >=0% and <3% of monthly income
* Moderate: >=3% and <=10%
* Major: >10%

Resolve ties by higher recurrence, then by stronger cross-domain impact.

5. Fatigue & Recovery Detection:
   Identify:

* rolling 7-day windows with 3+ short-sleep nights (high-severity recovery disruption)
* repeated post-02:00 bedtime clusters
* cumulative sleep debt
* early wake disruptions
* failed rebound after holidays, events, or travel

Highlight behavioral clusters, not isolated incidents.

6. Goal Anchoring:
   Evaluate how anomalies affect:

* fitness consistency
* walking activity
* active recovery
* budget stability
* work structure
* long-term lifestyle sustainability

Reference average daily steps ({{avgSteps}} avg/day) when evaluating activity consistency.

7. Recommendation Constraints:
   Avoid generic advice.

Every recommendation must include:

* a measurable target
* a numeric threshold
* or a behavioral trigger tied directly to observed data.

Prefer quantified observations over descriptive narration.

Avoid:

* filler
* motivational language
* vague productivity advice
* repetitive phrasing''';

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

Keep output:

* punchy
* data-dense
* analytical
* metric-focused

Determinism rules:

* In **Patterns & Anomalies**, list top 3 anomalies first (ranked by severity, recurrence, cross-domain impact).
* Keep each anomaly bullet to 2 concise sentences maximum.
* Prefer quantified claims (counts, percentages, ranges, deltas) over narrative wording.
* If any domain data is missing/excluded, state "Domain excluded or insufficient data" for that domain without fabrication.

### **Patterns & Anomalies**

* **[Metric Name]:** [Observation with exact data]. [Impact with explicit confidence or uncertainty when evidence is partial].
* **[Metric Name]:** [Observation with exact data]. [Cross-domain implication tied to behavior, schedule, or spending].

### **Clear Next Actions ({{checklistMonth}})**

The checklist must cover the **entire month** of {{checklistMonth}} as **{{checklistWeekCount}} weekly segments**.

Rules:

* Do not merge weeks.
* Do not skip partial weeks.
* Do not reorder week segments.
* Use the exact week ranges from the provided list.
* Weekly targets must adapt to holidays, travel, and recovery load.
* Assume Sun–Thu are primary work/productivity days.
* Use Fri–Sat for recovery, errands, mobility maintenance, and social obligations.
* Reduce intensity during post-holiday recovery weeks.

{{checklistWeekSegments}}

For **each** week listed above, repeat this structure exactly:

* Output one block per listed week segment, in the same order, with no omissions.

##### **Week [N] · [exact range from list]**

#### **1. Health & Sleep**

* [Actionable Directive]: [Exact sleep, steps, hydration, or recovery target for this week only].

#### **2. Expenses & Cashew App**

* [Actionable Directive]: [Exact spend cap, logging task, no-buy rule, or recovery action].

#### **3. Location & Mobility**

* [Actionable Directive]: [Exact ride distance, commute optimization, or fuel target].

#### **4. Gaming & Leisure**

* [Actionable Directive]: [Exact wind-down routine, gaming limit, or screen-time restriction].

#### **5. Calendar & Schedule**

* [Actionable Directive]: [Exact adjustment tied to workdays, events, holidays, or recovery scheduling].''';

  static const focusHeader = 'Focus instructions:';
}
