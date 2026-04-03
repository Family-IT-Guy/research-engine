---
name: research-engine:retrieve
description: >-
  Knowledge retrieval from research files. Invoke when the user asks "what do we
  know about X?", "have we researched X?", "any notes on X?", or before
  dispatching new research to check existing coverage.
  Also used by :orchestrate for batch coverage checks.
---

# Research Engine: Retrieve

Search existing research files, present results, assess coverage, and offer to
fill gaps via :orchestrate.

## Extension File

If `~/.claude/research-engine.md` exists, read its Coverage Sources section
for additional systems to search alongside the base research file search.

## Workflow

### Step 1: Search

**Base search** (always):

Search the research output directory (default `./research/`, or as configured
in the extension file's Settings):

```
./research/*.md
```

Use Glob to find candidate files by name, then Grep to search content for
keyword relevance. For matches, Read the first 20 lines to extract YAML
frontmatter (research_id, depth, date, source_type).

If the research directory doesn't exist, report 0 hits.

**Extension search**: If `~/.claude/research-engine.md` defines Coverage
Sources, run those additional searches in parallel. Each source handles its
own unavailability gracefully — never let one failure block the others.

### Step 2: Present Results

Present results grouped by source:

```
RESEARCH FILES:
  - [topic-slug-YYYY-MM-DD.md]: "[first line of findings]" (depth, date)

[Extension source results, if any, in their own sections]

NO RESEARCH FOUND ON: [topic] (if nothing found anywhere)
```

### Step 3: Assess Coverage

Based on search results:

| Level | Criteria |
|-------|----------|
| **Full** | Dedicated research thread exists, recent, on-topic |
| **Partial** | Research exists but doesn't fully cover the topic |
| **None** | No hits |
| **Stale** | Research exists but is older than 30 days |

Present assessment and offer options:

- **Full**: "This topic has been researched. Want to read the details or refresh?"
- **Partial/Stale**: "Partial coverage exists. Want to research the gaps?"
- **None**: "No existing research on this topic. Want me to research it?"

If user wants to proceed, hand off to :orchestrate.

### Step 4: Drill Down (Optional)

If user requests detail on a specific result:

1. Read the full content of the selected file
2. Present a summary with:
   - Key findings
   - Sources cited
   - Confidence assessment
   - Date and depth of research
   - Any open questions or gaps noted

## Batch Mode (Quick-Status)

When called by :orchestrate (mode = `quick-status`), skip presentation and
return structured data only:

```yaml
topic: "<search query>"
coverage: full | partial | none | stale
research_ids: [RE-2026-0403-001, ...]
hit_count: <total hits>
```

This allows batch processing — :orchestrate can check coverage for multiple
topics in rapid succession without verbose output.

## Error Handling

If the research directory doesn't exist, report 0 hits (not an error — it
just means no research has been conducted in this project yet).

If extension sources are unavailable, note which systems couldn't be reached
so the user knows the coverage assessment may be incomplete.
