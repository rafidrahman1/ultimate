/// Markdown shape expected by [InsightParser], [parseInsightReport], and
/// [InsightsDashboard] / [WeeklyInsightsDashboard].
const kInsightOutputFormatInstructions = '''
OUTPUT FORMAT (required — follow exactly):

Do not write an intro (no "Here is your…" paragraph). Start directly with the first section header.

### **Patterns & Anomalies**

Write 2–4 bullets. Each bullet must use this shape on its own line:
*   **Short pattern title:** One or two sentences citing specific numbers from the data only.

Bold key metrics inline, for example: **4,017 steps**, **5h 56m**, **72 bpm**, **500 BDT**, **175.8 km**, **22 trips**.

Cover health/sleep, spending, and mobility/transport when the data includes them. If a domain has no data, one bullet stating that.

---

### **Clear Next Actions (Next 7 Days)**

Group actions under numbered #### subsections (3 groups when possible):

#### **1. Health & Sleep (short subtitle)**
*   **Action headline:** Concrete step for the next 7 days with bold numeric targets.

#### **2. Expenses (short subtitle)**
*   **Action headline:** Concrete spending or budget step with bold amounts in BDT when relevant.

#### **3. Transport (short subtitle)**
*   **Action headline:** Concrete mobility habit with bold step or distance targets when relevant.

Formatting rules:
- Use exactly two ### main sections (Patterns, then Actions) and #### for action groups only.
- Use * bullets (asterisk + three spaces), not top-level numbered lists.
- Put --- on its own line between the two main sections.
- Use only facts from the provided data; do not invent metrics.
- No JSON, no code fences, no extra sections after the action plan.
''';

/// Short system preamble for API calls (pairs with the user prompt).
const kInsightOutputSystemMessage =
    'You are a personal insights assistant. Reply only in the markdown structure '
    'specified in the user message. No preamble, no JSON, no code fences. '
    'Every metric must come from the user\'s data.';
