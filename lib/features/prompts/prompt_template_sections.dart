/// Fixed prompt sections — not user-editable in the Prompts screen.
abstract final class PromptTemplateSections {
  static const rulesForAnalysis = '''
RULES FOR ANALYSIS:

1. Cross-Domain Causality:
   Explicitly connect calendar events, holidays, travel, late-night routines, and lifestyle disruptions to measurable impacts on:

* sleep duration
* bedtime drift
* recovery quality
* step averages
* discretionary spending
* fuel usage
* workday consistency

Only mention relationships directly supported by the provided data.

2. Financial Contextualization:
   Use {{monthlyIncomeBdt}} BDT as the financial baseline.

Calculate percentages for:

* discretionary spending
* electronics purchases
* gifts
* restaurant spikes
* fuel patterns

Classify financial impact:

* Minor: <3% of monthly income
* Moderate: 3–10%
* Major: >10%

Prioritize anomalies by financial impact severity.

3. Fatigue & Recovery Detection:
   Identify:

* consecutive short-sleep sequences
* repeated post-02:00 bedtimes
* cumulative sleep debt
* early wake disruptions
* failed recovery after holidays, events, or travel

Highlight behavioral clusters, not isolated incidents.

4. Goal Anchoring:
   Evaluate how anomalies affect:

* fitness consistency
* walking activity
* active recovery
* budget stability
* work structure
* long-term lifestyle sustainability

Reference average daily steps ({{avgSteps}} avg/day) when evaluating activity consistency.

5. Recommendation Constraints:
   Avoid generic advice.

Every recommendation must include:

* a measurable target
* a numeric threshold
* or a behavioral trigger tied directly to observed data.

Keep observations compact, analytical, and insight-dense.

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

Keep sentences:

* punchy
* data-dense
* analytical
* metric-focused

### **Patterns & Anomalies**

* **[Metric Name]:** [Observation with exact data]. [Direct impact on recovery, fitness consistency, work structure, or budget stability].
* **[Metric Name]:** [Observation with exact data]. [Cross-domain implication tied to behavior, schedule, or spending].

### **Clear Next Actions ({{checklistMonth}})**

The checklist must cover the **entire month** of {{checklistMonth}} as **{{checklistWeekCount}} weekly segments**.

Rules:

* Do not merge weeks.
* Do not skip partial weeks.
* Weekly targets must adapt to holidays, travel, and recovery load.
* Assume Sun–Thu are primary work/productivity days.
* Use Fri–Sat for recovery, errands, mobility maintenance, and social obligations.
* Reduce intensity during post-holiday recovery weeks.

{{checklistWeekSegments}}

For **each** week listed above, repeat this structure exactly:

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
