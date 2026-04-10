# Research Engine: Orchestration Reference

Detailed templates, definitions, and workflow for the orchestrate skill.

## Orchestration Workflow

Scan inputs for researchable topics, check existing coverage, get user approval,
and dispatch background sub-agents. This is the only user-facing research
dispatch skill. The :execute skill is internal and should never be invoked
directly.

Two entry paths:
1. **On-demand**: user provides a specific topic, voice memo, email, or note
2. **Scheduled**: an external system provides a pre-collected research queue
   (e.g., a daily brief or meeting prep system) — skip extraction, start at
   coverage check

### Extension File

If `~/.claude/research-engine.md` exists, read it once at the start of this
workflow. It may define:
- **Coverage Sources**: additional systems to search during Step 3
- **Post-Research Hooks**: actions to run after Step 5.5
- **Settings**: overrides for output directory, tools, and paths

Apply these extensions at the points noted in each step below.

### Step 1: Determine Input Source

**If called with a specific note/email/topic:**

Read the full content of the input. Record:
- `source_type`: one of `voice-memo`, `email`, `note`, `manual`
- `source_ref`: filename, email ID, or topic string

**If called by an external system (scheduled):**

Receive the collected research queue items. Each item already has `source_type`
and `source_ref`. Skip Step 2 and proceed to Step 3.

### Step 2: Extract Researchable Topics

Apply LLM judgment to the input text. Use the topic extraction checklist
below as a light nudge (not an exhaustive filter).

For each identified topic, generate:

| Field | Description |
|-------|-------------|
| topic_name | Concise, 3-8 words |
| why_researchable | One sentence: what knowledge gap exists |
| research_query | Specific, actionable query (sharp enough for Perplexity) |
| source_reference | Which line/section of the input it came from |
| recommended_depth | `quick` or `deep` (see depth tiers below) |

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

### Step 4: Present Research Plan and Proceed

**Approval modes** (determined by the calling context or extension file):

- **auto-proceed** (recommended for health/medical contexts): Inform the user
  what you're researching and dispatch immediately. No approval gate. The user
  can interrupt or redirect, but the default is forward motion.
- **confirm** (default for general use): Present the plan, wait for the user
  to approve before dispatching.

If the calling context (e.g., a project CLAUDE.md) instructs auto-proceed,
skip the approval wait — present the plan as informational and go directly
to Step 5.

**Presenting the plan** (both modes):

Present a conversational summary. Keep it natural.

For auto-proceed, frame as informational: "I'm looking into [topics] for you."
For confirm mode, frame as a question: "I found [N] things worth researching.
Want me to look into these?"

For each topic:
- State the topic name in plain language
- One sentence on why it matters or what gap it fills
- Coverage status in natural language if relevant:
  - `none` -> "nothing in your files yet"
  - `partial` -> "we have some research but it's incomplete"
  - `stale` -> "we have research but it's [N] days old"

Do not present depth choices to the user. The system picks the appropriate
depth based on the topic's importance and coverage status. Do not show
research IDs, query strings, source_type, source_ref, or variable names.
These are internal.

In confirm mode, end with: "Want me to look into these? You can skip any
you don't need." Accept natural language responses.

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

**Handling user responses (confirm mode only):**

Accept natural language: "go ahead", "looks good", "skip the second one",
etc. If the user approves without changes, proceed with the system's
recommended depths.

### Step 5: Generate Research IDs and Dispatch Sub-Agents

**Generate all research IDs before dispatching any sub-agents** to avoid race
conditions. Use the ID generation script below
(format: `RE-YYYY-MMDD-NNN`, sequential based on existing thread files for
today's date).

**Per-topic dispatch routing:**
For each approved topic, use exactly ONE of these paths:
- Standard topic (not an upgrade candidate): use the standard dispatch template
- User chose "deep (upgrade)": use the **upgrade dispatch procedure** below
- User chose "deep (fresh)": use the standard dispatch template with `depth: deep`

For each approved topic, dispatch a background sub-agent using the Agent tool
with `run_in_background: true` and `subagent_type: "research-executor"`. Use
the sub-agent dispatch template below, filling in all variables:

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
5. Dispatch using the cascade child dispatch template below

### Step 5.1: Monitor Progress

After dispatching sub-agents, do not go silent. The user should never wonder
whether something is still happening.

**Every 60 seconds:** Read the last 30 lines of each running sub-agent's
output file. Report progress in plain language:

- What the agent is currently doing ("reading primary sources", "analyzing
  the Perplexity response", "writing the research file")
- How many sources it has found so far (if visible in the output)

Keep updates to one or two sentences. Don't repeat the same status if nothing
has changed — just say "still working on [topic]."

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
   cascade child dispatch template below

When building cascade child parameters:
- Copy `cascade_chain` from the parent's cascade YAML as-is
- Copy `context_for_next_agent` into the `context_from_parent` parameter
- Inherit `source_type` and `source_ref` from the original parent

5. Continue until no more cascades or user says stop

### Error Handling

- If sub-agent dispatch fails, report the failure and the topic to the user.
  Offer to retry.
- If a sub-agent returns an error instead of a summary, surface it with the
  topic name and research_id. Do not auto-retry API key or auth errors.

---

## Topic Extraction Checklist

When scanning input text for researchable topics, look for:

- **People**: Names mentioned in professional/expert contexts
- **Claims**: Factual assertions that could be verified or investigated
- **Decisions**: Choices that would benefit from evidence
- **Tools/Products**: Technologies, frameworks, services worth evaluating
- **Concepts**: Technical or domain terms worth understanding deeply
- **URLs**: YouTube links (ingest transcript as primary source), article links (read for context)

Not every mention warrants research. Apply judgment: is the user likely to act on this information, or is it passing context?

## YouTube Transcript Ingestion

When a YouTube URL appears in input or is found during research, ingest the transcript as a primary source using yt-dlp (must be installed):

```bash
yt-dlp --dump-json --skip-download "VIDEO_URL"
```

The JSON output includes `title`, `channel`, `view_count`, and more. Extract the transcript and save to `research/sources/TIMESTAMP_youtube-VIDEO_ID.md` alongside other primary source files.

If `~/.claude/research-engine.md` exists and defines a `youtube_tool` in Settings, use that command instead.

## Depth Tiers

### Quick Scan
- Single sonar-reasoning-pro call
- Perplexity synthesis only, no primary source fetching
- Cost: ~$0.01-0.05
- Use for: factual lookups, simple comparisons, current event checks

### Deep Dive
- May use sonar-deep-research for the initial call
- Fetches and reads primary sources cited by Perplexity
- Assesses completeness, writes cascade requests for gaps
- Cost: ~$0.10-5.00+ (depends on source count and model)
- Use for: high-stakes decisions, due diligence, academic review, anything that matters

## Cascade Rules

A sub-agent writes a cascade request (`research/cascades/[research_id]-cascade.yml`) when:

- A critical sub-question could not be answered
- Sources explicitly disagreed and resolution requires focused research
- A lead from primary sources opens a significant new angle
- Sources were blocked and their content is needed

Do NOT cascade for minor gaps or tangential curiosity.

### cascade_chain Format

Traces full research ancestry. Each entry is added by the sub-agent that creates the cascade:

```yaml
cascade_chain:
  - id: RE-2026-0403-001
    topic: "original topic"
    key_finding: "one-line summary of what was found"
  - id: RE-2026-0403-002
    topic: "follow-up topic"
    key_finding: "what this round discovered"
```

The next sub-agent inherits the full chain and adds itself.

## Research ID Generation

Format: `RE-YYYY-MMDD-NNN` — sequential per calendar day.

Generate all IDs BEFORE dispatching sub-agents to avoid race conditions.

Use pplx-curl.sh:

```bash
pplx-curl.sh --next-id [research_dir] [count]
```

Examples:
- `pplx-curl.sh --next-id` — one ID, default `./research/` directory
- `pplx-curl.sh --next-id ./research 3` — three sequential IDs

## Sub-Agent Dispatch Templates

### Standard Dispatch

```
You are a research sub-agent. Follow the research-engine:execute skill exactly.

Parameters:
- query: "{{QUERY}}"
- depth: "{{DEPTH}}"
- research_id: "{{RESEARCH_ID}}"
- source_type: "{{SOURCE_TYPE}}"
- source_ref: "{{SOURCE_REF}}"
- triggered_by: "{{TRIGGERED_BY}}"

Instructions:
1. Find and read the execute skill file (skills/execute/SKILL.md in the research-engine plugin)
2. Execute the {{DEPTH}} scan workflow
3. Return your structured summary when complete

Do NOT present a research plan or wait for approval. Execute immediately.
```

### Cascade Child Dispatch

```
You are a research sub-agent executing a CASCADE follow-up.

Parameters:
- query: "{{QUERY}}"
- depth: "{{DEPTH}}"
- research_id: "{{RESEARCH_ID}}"
- source_type: "{{SOURCE_TYPE}}"
- source_ref: "{{SOURCE_REF}}"
- triggered_by: "{{TRIGGERED_BY}}"

Cascade context:
- cascade_chain_yaml: |
{{CASCADE_CHAIN_YAML}}
- context_from_parent: |
{{CONTEXT_FROM_PARENT}}

Instructions:
1. Find and read the execute skill file (skills/execute/SKILL.md in the research-engine plugin)
2. Execute the {{DEPTH}} scan workflow
3. Use cascade context to BUILD ON prior findings — do not re-discover what the parent already found
4. Return your structured summary when complete

Do NOT present a research plan or wait for approval. Execute immediately.
```

## Variable Reference

| Variable | Source | Description |
|----------|--------|-------------|
| QUERY | Step 2 topic extraction or user input | The specific research query |
| DEPTH | Step 4 user approval | "quick" or "deep" |
| RESEARCH_ID | Step 5 ID generation | Pre-generated, e.g. RE-2026-0403-001 |
| SOURCE_TYPE | Step 1 input detection | manual, voice-memo, email, note |
| SOURCE_REF | Step 1 input detection | Filename, email ID, or topic string |
| TRIGGERED_BY | Calling context | on-demand, scheduled |
| CASCADE_CHAIN_YAML | Parent cascade file | Full ancestry as YAML |
| CONTEXT_FROM_PARENT | Parent cascade file | Extracted findings + investigation targets |
