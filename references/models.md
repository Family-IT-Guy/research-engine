# Perplexity Sonar Models Reference

## Models

Two models. Simple selection.

| Model | Use Case | Pricing (per 1M tokens) | Request Fee (per 1K requests) |
|-------|----------|------------------------|------------------------------|
| sonar-reasoning-pro | All queries (DEFAULT) | $2 input / $8 output | $6 / $10 / $14 (low/med/high search context) |
| sonar-deep-research | Exhaustive, report-style research | $2 input / $8 output | + reasoning $3/1M, citations $2/1M, searches $5/1K |

## Model Selection

Binary decision:

**Is this exhaustive, report-style research requiring dozens of sources?**
- **Yes** → `sonar-deep-research`
- **No** → `sonar-reasoning-pro`

That's it. No other models needed.

**Why not sonar or sonar-pro?** sonar-reasoning-pro is cheaper than sonar-pro on output tokens ($8 vs $15/1M) and adds reasoning traces. sonar is unnecessary when reasoning-pro handles simple queries equally well at marginal cost difference.

**IMPORTANT: search_context_size nesting:** This parameter must be inside `web_search_options`, NOT at the top level. Top-level placement is silently ignored (falls back to "low" at $6/1K). Correct format: `"web_search_options": {"search_context_size": "high"}`. Verified Feb 2026.

---

## sonar-reasoning-pro

**Default model for all queries.**

**Capabilities:**
- Real-time web search with reasoning traces
- Step-by-step inference visible in `<think>` tags
- Causal reasoning, trade-off analysis, evaluations
- Structured output support (json_schema, regex)
- Academic, SEC, and web search modes

**Optimal for:**
- All factual lookups and current events
- "Why" and "how" questions requiring logical chains
- Complex trade-off analysis
- Technical and mathematical problems
- Research synthesis across multiple domains
- Root cause analysis and debugging (mandatory for RCA)
- Fact-checking and verification

**Default parameters (always set):**
- `search_context_size`: `"high"`
- `return_related_questions`: `true`
- `temperature`: `0.2`
- `stream`: `false`

---

## sonar-deep-research

**Autonomous research agent for exhaustive investigations.**

**Capabilities:**
- Runs dozens of searches autonomously (~30 queries typical)
- Processes hundreds of sources
- 128K token context window
- Generates structured, multi-section reports
- Supports `reasoning_effort` parameter

**Optimal for:**
- Exhaustive, report-style research
- Due diligence and comprehensive analysis
- Academic literature review
- Competitive intelligence
- Market research and trend analysis
- Topics requiring dozens of sources

**Default parameters (always set):**
- `search_context_size`: `"high"` (must be inside `web_search_options`)
- `reasoning_effort`: `"high"`
- `return_related_questions`: `true` (note: deep research may not return related questions despite this being set)
- `temperature`: `0.2`
- `stream`: `false`

**Response includes additional usage fields:**
- `reasoning_tokens` — tokens used for internal reasoning
- `citation_tokens` — tokens used for citation processing
- `num_search_queries` — number of autonomous searches performed
- `usage.cost` — actual dollar cost breakdown (note: field is `search_queries_cost`, not `search_units_cost`)

**Timeout note:** Deep research can take 30-120+ seconds. For timeout-prone environments, use the async API endpoint (`/async/chat/completions`). See api-reference.md for async request format (requires `request` wrapper).

---

## Multi-Model Synthesis Patterns

### When to Use Multi-Model

With our two-model setup (sonar-reasoning-pro + sonar-deep-research), multi-model research is straightforward: use both when you need comprehensive coverage AND deep analysis.

**Use multi-model when:**
- Exhaustive research needs analytical synthesis
- High-stakes decisions requiring maximum confidence
- Topic warrants both broad coverage and causal reasoning

**Most queries use a single model.** Multi-model is the exception, not the rule.

### The Pattern: Analysis + Exhaustive Research

**Sequence:**
1. **sonar-deep-research** → Exhaustive investigation, dozens of sources, comprehensive report
2. **sonar-reasoning-pro** → Analyze the deep research findings, identify causal relationships, evaluate trade-offs, synthesize conclusions

**Why this order:** Deep research gathers the raw material. Reasoning-pro applies analytical rigor to that material.

**Example queries:**
- "Comprehensive analysis of the electric vehicle market through 2030" (deep-research gathers data, reasoning-pro analyzes trends)
- "Should we migrate from PostgreSQL to CockroachDB?" (deep-research surveys landscape, reasoning-pro evaluates trade-offs)
- "Research the regulatory landscape for AI in healthcare" (deep-research maps regulations, reasoning-pro identifies implications)

### Synthesis Guidelines

#### Confidence Scoring

| Agreement | Confidence | Presentation |
|-----------|------------|--------------|
| Both models agree | High | State as established finding |
| Minor variations | Medium-High | State with "generally" qualifier |
| Models conflict | Low | Flag conflict explicitly, analyze why |

#### Handling Conflicts

When findings disagree:

1. **State the conflict explicitly**: "Deep research found X, while reasoning analysis concluded Y"
2. **Analyze why**: Different sources? Different reasoning approaches? Different time frames?
3. **Present both views**: Don't hide the disagreement
4. **Offer assessment**: Which seems more reliable and why?
5. **Let user decide**: Don't force a conclusion

#### Output Structure

```markdown
## Summary
[Synthesized key finding]

## Deep Research Findings (sonar-deep-research)
- Finding 1 [source]
- Finding 2 [source]
...

## Analysis (sonar-reasoning-pro)
- Reasoning chain...
- Conclusion...

## Synthesis

### Areas of Agreement
### Areas of Conflict (if any)
### Confidence Assessment

## Sources
[Combined from both models, deduplicated]
```

### When NOT to Multi-Model

Single model is sufficient (and preferred) when:
- Query is well-defined with clear scope → reasoning-pro
- Quick factual lookup → reasoning-pro
- User explicitly requests speed → reasoning-pro
- Already have comprehensive data, just need analysis → reasoning-pro
- Need exhaustive data but not deep analysis → deep-research
