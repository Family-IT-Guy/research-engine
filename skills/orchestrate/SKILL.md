---
name: research-engine:orchestrate
description: >-
  Deep web research via Perplexity Sonar API with cited sources, reasoning
  traces, and persistent research threads. ALWAYS use instead of WebSearch,
  WebFetch, and firecrawl for: (1) Any research request ("research this",
  "look into", "find out about", "what's the latest on"), (2) Current events,
  news, recent developments, (3) Fact-checking or verifying claims,
  (4) Cross-library comparisons, architecture decisions, technology landscape
  research (use context7 for single-library docs only), (5) Market research,
  competitive analysis, business intelligence, (6) Troubleshooting, debugging,
  root cause analysis, (7) Any question needing web-grounded cited data.
  Triggers: "research", "look up", "search for", "investigate", "deep dive",
  "what do we know about", "dig into". Extracts topics from voice memos,
  emails, and notes. Dispatches background sub-agents for parallel research.
---

# Research Engine: Orchestrate

Scan inputs for researchable topics, check existing coverage, get user approval,
and dispatch background sub-agents. This is the only user-facing research
dispatch skill. The :execute skill is internal and should never be invoked
directly.

Two entry paths:
1. **On-demand**: user provides a specific topic, voice memo, email, or note
2. **Scheduled**: an external system provides a pre-collected research queue
   (e.g., a daily brief or meeting prep system) — skip extraction, start at
   coverage check

## Extension File

If `~/.claude/research-engine.md` exists, read it once at the start of this
workflow. It may define:
- **Coverage Sources**: additional systems to search during Step 3
- **Post-Research Hooks**: actions to run after Step 5.5
- **Settings**: overrides for output directory, tools, and paths

Apply these extensions at the points noted in each step below.

## Workflow

### Step 1: Determine Input Source

**If called with a specific note/email/topic:**

Read the full content of the input. Record:
- `source_type`: one of `voice-memo`, `email`, `note`, `manual`
- `source_ref`: filename, email ID, or topic string

**If called by an external system (scheduled):**

Receive the collected research queue items. Each item already has `source_type`
and `source_ref`. Skip Step 2 and proceed to Step 3.

### Step 2: Extract Researchable Topics

Apply LLM judgment to the input text. Use the topic extraction checklist in
`references/orchestration.md` as a light nudge (not an exhaustive filter).

For each identified topic, generate:

| Field | Description |
|-------|-------------|
| topic_name | Concise, 3-8 words |
| why_researchable | One sentence: what knowledge gap exists |
| research_query | Specific, actionable query (sharp enough for Perplexity) |
| source_reference | Which line/section of the input it came from |
| recommended_depth | `quick` or `deep` (see depth tiers in `references/orchestration.md`) |

Not every mention warrants research. Apply judgment: is the user likely to act
on this information, or is it passing context? When in doubt, extract it — the
user decides what to keep in Step 4.

### Step 3: Check Existing Coverage

For each extracted topic, search for existing research:

**Base search** (always): Glob `./research/*.md` (or the configured output
directory). Use Grep to search content for keyword relevance. For matches,
Read the first 20 lines to extract YAML frontmatter (research_id, depth, date,
source_type). If the research directory doesn't exist, report 0 hits.

**Extension search**: If `~/.claude/research-engine.md` defines Coverage
Sources, run those additional searches in parallel alongside the base search.
Each extension source handles its own unavailability gracefully.

The return structure:

```yaml
topic: "<topic string>"
coverage: full | partial | none | stale
research_ids: [...]
hit_count: <N>
```

Filter decisions:
- **full**: drop (already researched)
- **stale**: keep, note it is a refresh
- **partial** or **none**: keep
- **upgrade candidate**: If coverage is `full`, check the depth of existing
  threads: read the YAML frontmatter of each file listed in `research_ids`.
  If ALL matched thread files have `depth: quick` (none has `depth: deep`),
  and the user's recommended or requested depth is `deep`, flag the topic as
  an upgrade candidate. Keep it in the list with a note:
  `upgrade_from: RE-YYYY-MMDD-NNN`.

  **To resolve a research_id to a file path:** Glob `./research/*-*.md`
  and read the first 5 lines of each result to find the file whose frontmatter
  `research_id` field matches.

If no topics remain after filtering, report: "All extracted topics already have
full research coverage. Nothing to dispatch." Then stop.

### Step 4: Present Research Plan to User

Present a conversational summary of all topics. Keep it natural — the user is
talking to a research partner, not reading a terminal. Detail is available on
request for power users.

**Summary view** (always show this first):

Write a natural introduction: "I found N topics worth researching from your
[source description]:" Then for each topic:

- State the topic name in plain language
- Describe coverage status conversationally:
  - `none` → "nothing in your files yet"
  - `partial` → "we have some research on this but it's incomplete"
  - `stale` → "we have research but it's [N] days old"
  - `full (upgrade candidate)` → "we did a quick search before, but this deserves a deeper look"
- State the recommended search approach:
  - `quick` → "a quick search should be enough" or "a quick update should cover it"
  - `deep` → "I'd recommend a thorough search on this one" or "this one deserves a deep look"

End with natural options, not format specifications:

```
Want me to go ahead with these? You can also:
- Change any topic to a quick or thorough search
- Skip a topic you don't need
- Ask me to explain what I'd look for on any topic

For example: "go ahead", "skip 2", "make 1 a quick search", or "tell me more about 1"
```

Do not show research IDs, query strings, source_type, source_ref, or variable
names in the summary. These are internal.

**Detail view** (show when user says "tell me more about N", "details", "what
exactly would you search for?", or similar):

For power users who want to see or adjust the technical parameters:

```
N. [Topic name]
   Objective: [What this research will answer]
   Query: "[the specific research query]"
   Model: [sonar-reasoning-pro / sonar-deep-research] — [rationale]
   Search mode: [web/academic/sec] — [rationale]

   Parameters:
   - return_images: [true/false]
   - Date filters: [suggest if applicable, omit if not]
   - Domain filters: [suggest if applicable, omit if not]

   Alternatives:
   - [Alternative framing] — might be better if [condition]

   Blind spots:
   - [What this approach might miss]
```

For upgrade candidates in detail view, also show:
```
   Prior research: [research_id, date]
   Options: build on the previous search, start fresh, or skip
```

**Handling user responses:**

Accept natural language: "go ahead", "looks good", "skip the second one",
"make them all quick", "do a thorough search on 1", etc. Also accept
structured formats like "1: deep, 2: quick" for power users.

If the user approves without specifying depths, use the recommendations from
the summary view.

### Step 5: Generate Research IDs and Dispatch Sub-Agents

**Generate all research IDs before dispatching any sub-agents** to avoid race
conditions. Use the ID generation script in `references/orchestration.md`
(format: `RE-YYYY-MMDD-NNN`, sequential based on existing thread files for
today's date).

**Per-topic dispatch routing:**
For each approved topic, use exactly ONE of these paths:
- Standard topic (not an upgrade candidate): use the standard dispatch template
- User chose "deep (upgrade)": use the **upgrade dispatch procedure** below
- User chose "deep (fresh)": use the standard dispatch template with `depth: deep`

For each approved topic, dispatch a background sub-agent using the Agent tool
with `run_in_background: true` and `subagent_type: "research-executor"`. Use
the sub-agent dispatch template from `references/orchestration.md`, filling in
all variables:

- `query`: the specific research query from Step 2
- `depth`: user's chosen depth from Step 4
- `research_id`: pre-generated ID
- `source_type`: from Step 1 (for cascade children, inherit from original parent)
- `source_ref`: from Step 1 (for cascade children, inherit from original parent)
- `triggered_by`: `on-demand` or `scheduled`

**For upgrade dispatches** (user chose "deep (upgrade)"):

1. Read the existing quick scan thread file
2. Extract: key findings, sources already consulted, related questions
3. Construct `context_from_parent` with findings and source list
4. Set `cascade_chain` with the quick scan as the first entry
5. Dispatch using the cascade child dispatch template from
   `references/orchestration.md`

Report to user: "Dispatched N research sub-agents. They will run in the
background."

### Step 5.5: Report Completion Stats

When all dispatched sub-agents have completed (or failed), present results
conversationally. Lead with what was found, not system metrics.

For each completed topic:
- State the topic name
- Summarize what was found (1-2 sentences of the key finding)
- Note source count: "found N sources"

If any searches failed, explain in plain language: "The search on [topic]
didn't work — [reason]. Want me to try again?"

If any agent used WebSearch fallback, explain: "I couldn't reach my usual
research source for [topic], so I used a simpler search instead. The results
may be less thorough. Want me to retry?"

If any agents requested cascades (follow-up questions), introduce them
naturally: "While researching [topic], I found a follow-up question worth
investigating: [cascade topic]. Want me to look into that too?"

End with cost if non-trivial: "(Research cost: $X.XX)"

Sum `cost` and `source_count` from each sub-agent's structured return summary
internally. For failed agents, note the failure reason. If any agents
requested cascades, proceed to Step 6.

**Extension point: Post-Research Hooks.** If `~/.claude/research-engine.md`
defines Post-Research Hooks, execute them now (after stats, before cascades).

### Step 6: Handle Cascade Returns

When a background sub-agent completes, check whether it wrote a cascade file
at `research/cascades/[research_id]-cascade.yml`.

If no cascade file exists, the research is complete.

If a cascade file exists:

1. Read the cascade YAML file
2. **Handle blocked sources** (if `blocked_sources` section exists):
   For each blocked URL, attempt to fetch the content using main-agent tools
   (which have full permissions unlike sub-agents):
   - Try **WebFetch** with a detailed prompt
   - If content is retrieved, save to `research/sources/` and append
     the key findings to the cascade's `context_for_next_agent` fields
   - If all methods fail, note it when presenting follow-ups
3. Present follow-up topics conversationally:

Introduce the cascade naturally: "While researching [parent topic], I found
[N] follow-up question(s) worth investigating:" Then for each follow-up:

- State what the gap is in plain language
- Explain why it matters (how it connects to the parent topic)
- Recommend a search depth using the same natural language as Step 4

If blocked sources were retrieved, mention it briefly: "I also pulled in some
sources that the initial search couldn't access."

End with: "Want me to look into these?" Accept natural language responses.

4. If approved, generate new research IDs and dispatch sub-agents using the
   cascade child dispatch template from `references/orchestration.md`

When building cascade child parameters:
- Copy `cascade_chain` from the parent's cascade YAML as-is
- Copy `context_for_next_agent` into the `context_from_parent` parameter
- Inherit `source_type` and `source_ref` from the original parent

5. Continue until no more cascades or user says stop

## Error Handling
- If sub-agent dispatch fails, report the failure and the topic to the user.
  Offer to retry.
- If a sub-agent returns an error instead of a summary, surface it with the
  topic name and research_id. Do not auto-retry API key or auth errors.

## References

Detailed templates and definitions live in the reference files. Do not duplicate
here.

- `references/orchestration.md` — Topic extraction checklist, depth tier
  definitions, cascade rules, research ID generation script, sub-agent dispatch
  templates (standard + cascade child), variable reference table
- `references/models.md` — Model capabilities and pricing
