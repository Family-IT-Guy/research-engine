# Root Cause Analysis Workflow

## Triggers

Use this workflow for: debugging, troubleshooting, "why is X happening", "what's causing", root cause analysis, failure investigation.

**Model**: sonar-reasoning-pro (mandatory - causal reasoning required)
**Default params**: `search_context_size: "high"` | `search_mode`: auto-detect (use `"academic"` for scientific/engineering root causes)

## Context Gathering (Before Hypotheses)

Before generating hypotheses, check for existing investigation context:

1. **Session Handoff**: `$PROJECT_ROOT/SESSION_HANDOFF.xml`
   - Extract: current_status, root_cause_hypothesis, tested_hypotheses (CLOSED)

2. **Session Guides**: `$PROJECT_ROOT/.claude/guides/*session*.md` (recent 3-5)
   - Extract: root cause chains, hypotheses tested, findings

3. **Previous Research**: `./research/` (search for related thread files)

### Skeptical Context Reading

When reading session files, classify claims:

| Claim Type | Confidence | Treatment |
|------------|------------|-----------|
| OBSERVED (logs, outputs, measurements) | High | Accept as evidence |
| CONCLUDED (root cause, explanation) | Medium | Verify before accepting |
| ASSUMED ("probably", speculation) | Low | Treat as untested hypothesis |
| CLOSED hypothesis | Variable | Was test definitive? Re-open if weak |

For each "closed" hypothesis, ask:
1. How was it ruled out? Definitive or circumstantial?
2. Could the test have been flawed?
3. Has environment changed since?

If closure was weak, re-open as ACTIVE.

## RCA Process

1. **Define problem precisely**
   - What is the symptom? When did it start? What changed?
   - Do not search until problem is clearly stated

2. **Generate hypotheses**
   - Query: "What commonly causes [symptom]?"
   - Use `search_mode: "academic"` for scientific, medical, or engineering root causes (peer-reviewed sources)
   - Use `search_mode: "web"` for software bugs, configuration issues, infrastructure problems
   - Generate >=3 distinct hypotheses before testing any
   - Check session context for CLOSED hypotheses (don't regenerate)

3. **Test systematically**
   - For each hypothesis, search for confirming AND disconfirming evidence
   - Use sonar-reasoning-pro to evaluate causal logic
   - Document: CONFIRMED / RULED OUT + evidence + reasoning

4. **Validate root cause**
   - Confirm identified cause explains ALL symptoms
   - If not, continue investigation

5. **Document investigation** (required)
   - Log full path to research thread using template below
   - Update SESSION_HANDOFF.xml tested_hypotheses section if exists

## Hypothesis Status Definitions

| Status | Definition | Action |
|--------|------------|--------|
| CLOSED | Conclusively tested | Do NOT revisit without new invalidating evidence |
| INCONCLUSIVE | Test was invalid/incomplete | May revisit with proper setup |
| SUPERSEDED | Replaced by different hypothesis | Reference successor |
| OPEN | Not yet tested | Active investigation target |

**Enforcement**: CLOSED means CLOSED. Context resets do not justify re-testing.

## Evidence-Based Language

**Prohibited in conclusions**: best, optimal, always, never, guaranteed

**Required**: may, could, potentially, typically, measured, documented

Frame findings as:
- "data indicates...", "testing confirms...", "documentation states..."

NOT:
- "this is definitely...", "clearly the answer is..."

## RCA System Prompt

When querying Perplexity for RCA:

> Investigate this problem systematically. Generate at least 3 hypotheses for possible causes. For each hypothesis, find evidence for AND against. Document what's ruled out and why. Confirm the root cause explains all symptoms before concluding.

When session context exists, add:

> Prior investigation context: [summary]
> CLOSED hypotheses (already ruled out, do NOT re-suggest): [list]
> ACTIVE hypotheses: [list]
> Focus on: new angles OR deepening active hypotheses.

## RCA Documentation Template

```markdown
## Problem: [precise statement]
## Context: [when started, what changed, environment]

## Session Context
- Continues: [session number/guide if applicable]
- Claims accepted: [list with confidence level]
- Claims challenged: [list with reasoning]

## Hypotheses Tested

### H1: [hypothesis]
- Evidence for: [citations]
- Evidence against: [citations]
- Status: CONFIRMED/RULED OUT/OPEN
- Reasoning: [causal chain]

### H2: [hypothesis]
...

## Root Cause: [conclusion]
## Confidence: [high/medium/low + why]
## Evidence Chain: [how conclusion follows from evidence]
## Sources: [all sources with credibility/recency notes]
```

## Source Quality Assessment

For each citation, note:
- **Credibility**: Official docs > technical blogs > forums > social media
- **Recency**: Publication date; flag if >1 year old for fast-moving topics
- **Relevance**: Direct evidence vs tangential mention
