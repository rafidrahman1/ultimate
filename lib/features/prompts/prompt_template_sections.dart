/// Fixed prompt sections — not user-editable in the Prompts screen.
abstract final class PromptTemplateSections {
  static const rulesForAnalysis = '''
RULES FOR ANALYSIS:
1. Cross-Reference Domains: Connect the dots between life events, holidays, and physical/financial metrics (e.g., how the Eid al-Adha holiday week or late bedtimes directly impacted sleep depth, fitness targets, and financial reserves).
2. Calculate Percentages: Contextualize all discretionary spending, massive gift expenses, and hardware upgrades against Rafid's {{monthlyIncomeBdt}} BDT monthly income baseline.
3. Anchor to Core Goals: Evaluate how anomalies affect fitness progression (avg {{avgSteps}} steps vs. active goals) and lifestyle recovery.''';

  static const dataToAnalyze = '''
DATA TO ANALYZE:
- Health ({{analysisMonth}}):
{{health}}

- Expenses:
{{expenses}}

- Location & Mobility:
{{location}}

- Gaming & Screen Time:
{{gameActivity}}

- Calendar & Schedule:
{{calendar}}''';

  static const outputFormat = '''
OUTPUT FORMAT:
Generate the response strictly using the following Markdown structure. Keep sentences punchy and data-dense.
### **Patterns & Anomalies**
* **[Metric Name]:** [Observation with exact data]. [Specific impact on Rafid's core goals, work schedule, or budget].
* **[Metric Name]:** [Observation with exact data]. [Specific impact on Rafid's core goals, work schedule, or budget].
### **Clear Next Actions ({{checklistMonth}})**
The checklist must cover the **entire month** of {{checklistMonth}} as **{{checklistWeekCount}} weekly segments** — output one block per week below; do not merge weeks or skip any segment.

{{checklistWeekSegments}}

For **each** week listed above, repeat this structure (week-specific targets only; tie actions to that week's dates, work Sun–Thu, and any holidays in range):

##### **Week [N] · [exact range from list]**
#### **1. Health & Sleep**
* [Actionable Directive]: [Exact metric or habit for this week only].
#### **2. Expenses & Cashew App**
* [Actionable Directive]: [Exact spend cap, Cashew task, or recovery step for this week].
#### **3. Location & Mobility**
* [Actionable Directive]: [Exact distance, commute, or fuel target for this week].
#### **4. Gaming & Leisure**
* [Actionable Directive]: [Exact wind-down or screen-time rule for this week].
#### **5. Calendar & Schedule**
* [Actionable Directive]: [Exact schedule adjustment for this week's events and work blocks].''';

  static const focusHeader = 'Focus instructions:';
}
