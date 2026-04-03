---
name: research-engine:query
description: >-
  Lightweight inline research via Perplexity Sonar API. Use for single-topic
  lookups, fact-checking, and quick questions that need cited answers but
  don't warrant full orchestration with background sub-agents. Runs in the
  main conversation. Presents a research plan before execution.
---

# Research Engine: Query

Lightweight inline research for single questions. Runs in the main
conversation (no background sub-agents). For multi-topic research, use
:orchestrate instead.

## Extension File

If `~/.claude/research-engine.md` exists, read its Settings section for
output directory overrides and tool preferences.

## Workflow

### Step 1: Understand the Question

Identify:
- The core question to answer
- `source_type`: where this came from (`manual` if typed, or from a
  document/email/note)
- `source_ref`: the question text or source identifier

### Step 2: Present Research Plan

Before executing, show the user what you're about to do:

```
RESEARCH QUERY:
  Topic: [concise topic name]
  Query: "[the specific query for Perplexity]"
  Model: [sonar-reasoning-pro / sonar-deep-research]
  Search mode: [web / academic / sec]
  Parameters: [any date/domain filters, return_images]

Proceed? (or modify)
```

If the user approves without changes, proceed. If they modify the query or
parameters, incorporate changes.

### Step 3: Generate Research ID

```bash
TODAY_ID=$(date +%Y-%m%d)
TODAY_FILE=$(date +%Y-%m-%d)
EXISTING=$(ls ./research/*-${TODAY_FILE}.md 2>/dev/null | wc -l | tr -d ' ')
NEXT=$(printf "%03d" $((EXISTING + 1)))
RESEARCH_ID="RE-${TODAY_ID}-${NEXT}"
```

Adjust the glob path if `output_directory` is overridden in the extension file.

### Step 4: Execute API Call

Locate `pplx-curl.sh` in the research-engine plugin's `scripts/` directory.

```bash
path/to/pplx-curl.sh --research "TOPIC_SLUG" '{"model":"MODEL_NAME","messages":[{"role":"system","content":"SYSTEM_PROMPT"},{"role":"user","content":"USER_QUERY"}],"web_search_options":{"search_context_size":"high"},"search_mode":"SEARCH_MODE","return_related_questions":true,"return_images":RETURN_IMAGES,"temperature":0.2,"stream":false}'
```

The `--research` mode handles:
- Creating `research/raw/`, `sources/`, `cascades/` directories
- Generating a timestamp for the filename
- Saving the API response to `research/raw/TIMESTAMP_TOPIC-SLUG.json`
- Printing the output file path as `OUTPUT_PATH=<path>`

### Step 5: Write Thread File

Use the **Write** tool to create `research/[topic-slug]-YYYY-MM-DD.md`
with YAML frontmatter:

```yaml
---
research_id: RE-2026-0403-001
query: "the query"
depth: quick
date: 2026-04-03
model: sonar-reasoning-pro
queries: 1
cost: 0.02
sources: 5
cascade_parent: null
source_type: manual
source_ref: "the question"
triggered_by: on-demand
---
```

Thread body follows the same format as the execute skill's thread file.

### Step 6: Present Results Inline

Present the findings directly in the conversation:

```
RESEARCH: [topic name]

[Key findings, synthesized and readable]

Sources:
[1] Title — URL
[2] Title — URL

Related questions:
- [if present]

**Thread file**: research/[topic-slug]-YYYY-MM-DD.md
**Cost**: $X.XX | **Sources**: N | **Model**: [model name]
```

**Extension point: Post-Research Hooks.** If `~/.claude/research-engine.md`
defines Post-Research Hooks, execute them after presenting results.

## Error Handling

Since :query runs in the main conversation, errors can be shown to the user:

- **API errors**: Show the error, suggest checking the API key or retrying
- **Irrelevant results**: Note the issue, offer to reformulate and retry
- **Fallback**: If Perplexity is unavailable, offer to use WebSearch/WebFetch
  as a degraded alternative. Flag the quality reduction.
