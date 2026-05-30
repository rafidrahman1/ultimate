/// Fixed prompt sections — not user-editable in the Prompts screen.
abstract final class PromptTemplateSections {
  static const rulesForAnalysis = '''
RULES FOR ANALYSIS:

1. Cross-Reference Domains: Connect the dots (e.g., did low sleep correlate with an expensive takeout order instead of making food at home?).

2. Calculate Percentages: Always contextualize spending against the {{monthlyIncomeBdt}} BDT monthly income baseline from system context.

3. Anticipate Logistics: If weekend travel is detected, apply preference for step-by-step routing and strict adherence to rules/procedures.''';

  static const dataToAnalyze = '''
DATA TO ANALYZE:


- Health (weekly averages unless noted):

{{health}}


- Expenses:

{{expenses}}


- Location & Mobility:

{{location}}''';

  static const outputFormat = '''
OUTPUT FORMAT:

Generate the response strictly using the following Markdown structure. Keep sentences punchy and data-dense.


### **Patterns & Anomalies**

* **[Metric Name]:** [Observation with exact data]. [Specific impact on Rafid's core goals, work schedule, or budget].

* **[Metric Name]:** [Observation with exact data]. [Specific impact on Rafid's core goals, work schedule, or budget].


### **Clear Next Actions (Next 7 Days)**

#### **1. Health & Sleep**

* [Actionable Directive]: [Exact metric to hit to support fitness goals].

#### **2. Expenses & Cashew App**

* [Actionable Directive]: [Exact budget constraint, Cashew App reconciliation task, or "Buy/Skip" feedback on recent purchases].

#### **3. Location & Mobility**

* [Actionable Directive]: [Exact movement or route habit based on timeline activity and motorcycle distance].
''';

  static const focusHeader = 'Focus instructions:';
}
