# Research Engine: Orchestration Reference

Detailed templates and definitions for the orchestrate and execute skills.

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
