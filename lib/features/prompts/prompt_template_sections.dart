/// Fixed prompt sections — not user-editable in the Prompts screen.
abstract final class PromptTemplateSections {
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

* sleep duration
* bedtime drift
* recovery quality
* step averages
* discretionary spending
* fuel usage
* workday consistency

Only state causal links directly supported by timestamps, counts, or numeric deltas in the data.

4. Financial Contextualization

Use {{monthlyIncomeBdt}} BDT as the monthly baseline.

Calculate percentages for:

* discretionary spending
* electronics purchases
* gifts
* restaurant spikes
* fuel patterns

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

* fitness consistency
* walking activity
* active recovery
* budget stability
* work structure
* long-term sustainability

Reference actual average daily steps ({{avgSteps}} avg/day) when evaluating activity consistency.

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

9. Progressive Activity Targets

If average daily steps are below 3,000:

Week 1:
* baseline + 1,000 steps/day

Week 2:
* baseline + 1,500 steps/day

Week 3:
* baseline + 2,000 steps/day

Week 4:
* baseline + 3,000 steps/day

Week 5:
* maintain highest achieved target

Do not recommend more than a 30% increase week-over-week unless required by travel or special events.

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

Electronics purchases should trigger a cooling-off period if:

* electronics spending exceeded 5% of monthly income

Cooling-off period:

* 30 days without additional electronics purchases

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

13. Adherence Score Optimization

Prefer actions that are likely to be completed.

Examples:

Prefer:
* 4,000 steps/day achieved consistently

over:
* 8,000 steps/day likely to fail

Prefer:
* bedtime before 01:00

over:
* bedtime before 23:00

when historical behavior is substantially later.

Optimize for consistency rather than perfection.

14. Recommendation Ranking

Within each week:

Priority 1:
* Sleep
* Recovery

Priority 2:
* Budget stability

Priority 3:
* Physical activity

Priority 4:
* Mobility optimization

Priority 5:
* Leisure adjustments

Higher-priority recommendations should receive stronger emphasis.

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
  {{calendar}}

* {{checklistMonth}} Week Blocks:
{{checklistWeekBlocks}}''';

  static const outputFormat = '''
  OUTPUT FORMAT:

Generate the response strictly using the following Markdown structure.

Determinism rules:

* In **Patterns & Anomalies**, list top 3 anomalies first (ranked by severity, recurrence, cross-domain impact).
* Keep each anomaly bullet to 2 concise sentences maximum.
* Prefer quantified claims (counts, percentages, ranges, deltas) over narrative wording.
* Do not fabricate anomaly bullets for domains explicitly excluded in the data block.
* Every recommendation must be traceable to data.
* Assign exactly one weekly theme (Recovery, Stabilization, Improvement, Maintenance, or Review) per week segment.
* Apply progressive targets, weekly themes, and recommendation priority order from the analysis rules.

### **Patterns & Anomalies**

* **[Metric Name]:** [Observation with exact data]. [Impact with explicit confidence or uncertainty when evidence is partial].
* **[Metric Name]:** [Observation with exact data]. [Cross-domain implication tied to behavior, schedule, or spending].

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
* If a domain is explicitly excluded in the data block, omit its #### subsection entirely from every weekly checklist block. Do not output "Domain excluded" or placeholder bullets for excluded domains.

{{checklistWeekSegments}}

For **each** week listed above, repeat the week block structure:

* Output one ##### week header per listed segment, in the same order, with no omissions.
* Include only #### subsections for domains present in DATA TO ANALYZE.
* Skip #### subsections entirely for excluded domains.

##### **Week [N] · [exact range from list] · [Theme: Recovery | Stabilization | Improvement | Maintenance | Review]**

#### **1. Health & Sleep**

* [Actionable Directive]: [Exact sleep, steps, hydration, or recovery target for this week only].

#### **2. Expenses & Cashew App**

* [Actionable Directive]: [Exact spend cap, logging task, no-buy rule, or recovery action derived from observed spending].

#### **3. Location & Mobility**

* [Actionable Directive]: [Exact ride distance, commute optimization, or fuel target].

#### **4. Gaming & Leisure**

* [Actionable Directive]: [Exact wind-down routine, gaming limit, or screen-time restriction].

#### **5. Calendar & Schedule**

* [Actionable Directive]: [Exact adjustment tied to workdays, events, holidays, or recovery scheduling].''';

  static const focusHeader = 'Focus instructions:';
}
