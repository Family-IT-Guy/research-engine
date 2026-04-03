# Research Engine Extensions

Personal extensions for Ben's research engine setup. This file goes at
~/.claude/research-engine.md (not committed to the plugin repo).

## Coverage Sources

Additional systems to search when checking existing coverage on a topic.
Run these in parallel alongside the base research file search.

### claude-mem

```
mcp__plugin_claude-mem_mcp-search__search  →  query: "<topic>", limit: 10
```

Review the returned index. Call `get_observations` only for IDs that look
relevant based on title/snippet. Do NOT fetch all results. Skip the timeline
step — the search index provides enough signal for coverage assessment.

### MyRAG (Voice Memos / Notes / Activity)

```bash
~/.claude/skills/myrag/scripts/session_context.sh query "<topic>"
```

Semantic + BM25 hybrid search across voice memos, Obsidian notes, and
MacMonitor activity logs. Requires Docker (script auto-starts it). Allow up
to 90 seconds for cold start.

### Video Inventory

```bash
sqlite3 ~/assistant/state/video-inventory.db \
  "SELECT f.filename, snippet(transcripts_fts, 0, '>>>', '<<<', '...', 30) \
   FROM transcripts_fts \
   JOIN transcripts t ON transcripts_fts.rowid = t.rowid \
   JOIN files f ON t.file_id = f.id \
   WHERE transcripts_fts MATCH '<topic keywords>' \
   LIMIT 10;"
```

Convert the topic into FTS5 query terms: lowercase, drop stop words, join
with spaces (implicit AND). For phrases, wrap in double quotes.

### YouTube Search

```bash
yt-dlp --dump-json --flat-playlist --skip-download "ytsearch5:<topic keywords>" 2>/dev/null | python3 -c "
import json, sys
for line in sys.stdin:
    d = json.loads(line)
    print(f'{d.get(\"id\")} | {d.get(\"title\", \"\")[:70]} | {d.get(\"channel\", \"\")} | views:{d.get(\"view_count\", \"?\")}')"
```

Returns up to 5 YouTube videos relevant to the topic. High view count +
relevant title = worth ingesting the transcript as a primary source during
deep dives.

### Error Handling

Each source may fail independently. Never let one failure block the others:

- **MyRAG**: Docker not running → report "MyRAG unavailable (Docker offline)"
- **Video inventory**: DB file missing → report "Video inventory unavailable"
- **claude-mem**: Daemon not running → report "claude-mem unavailable"
- **YouTube search**: yt-dlp not installed or network error → report "YouTube search unavailable"

Always present whatever results were obtained. Note unavailable systems so the
user knows coverage assessment may be incomplete.

### Coverage Presentation

When presenting results, group by source system:

```
FROM RESEARCH FILES:
  - [file]: "[summary]" (depth, date)

FROM CLAUDE-MEM:
  Obs #[id]: "[title]" (type, date, project)

FROM MYRAG (voice memos/notes):
  "[snippet]" (source type, date)

FROM VIDEO INVENTORY:
  "[filename]": "[transcript snippet]"

NOT FOUND IN: [systems with no hits]
```

In quick-status mode, return per-system counts:

```yaml
hits_by_system:
  research_files: <N>
  claude_mem: <N>
  myrag: <N>
  video_inventory: <N>
  youtube_search: <N>
unavailable_systems: []
```

## Post-Research Hooks

### Source Document Annotation

After sub-agents complete (orchestrate Step 5.5), annotate the original source
document so the user can see that research was conducted. Run this step once
per original dispatch — annotate after the first sub-agent returns, regardless
of whether cascades follow. Cascade children do not trigger additional
annotations.

1. Extract `source_type` and `source_ref` from the dispatch parameters
2. **Resolve note path by source_type:**
   - `voice-memo` or `note`: Glob for the filename in the Obsidian vault
     (`~/Documents/notes-vault/notes-vault/`). Use the basename of `source_ref`
     as the search pattern.
   - `email`: Skip file annotation (emails are not editable files). Instead,
     if a daily log exists for today at
     `~/assistant/state/daily-logs/YYYY-MM-DD.yml`, append to its
     `research_dispatched` array:
     ```yaml
     research_dispatched:
       - source_ref: "email subject"
         research_id: RE-2026-0403-001
         depth: deep
         date: 2026-04-03
     ```
     If no daily log exists for today, skip annotation and warn the user:
     "No daily log found for today. Email research annotation skipped."
   - `manual`: Skip annotation entirely (no source document).
3. **Read the note** and check whether a `> [!research]` callout already exists
   (search for the string `> [!research]`)
4. **If no callout exists:** Use the Edit tool to insert a callout block
   immediately after the YAML frontmatter closing `---` (the second `---` line).
   Insert a blank line, then the callout, then a blank line:
   ```markdown

   > [!research] Research conducted
   > - {research_id}: {topic_slug} ({depth}, {date})

   ```
   If the note has no YAML frontmatter (no opening `---` on line 1), insert
   the callout block at the very beginning of the file.
5. **If callout exists:** Use the Edit tool to append a new entry to the existing
   callout. Construct `old_string` as a two-line block: the line immediately before
   the last `> - RE-` entry (either the callout header or the previous entry) plus
   the last `> - RE-` entry itself. Set `new_string` to that same two-line block
   with the new `> - {research_id}: {topic_slug} ({depth}, {date})` line appended.
6. **If Glob finds no matching note:** Warn the user:
   "Could not find source note '[source_ref]' in vault. Research completed but
   source annotation skipped." Do NOT fail the workflow.

## Settings

output_directory: research-output
youtube_tool: python3 ~/.claude/skills/youtube-ingest/scripts/ingest.py "{VIDEO_URL}" --json
legacy_search_paths: .claude/perplexity-research/*.md, research-output/*.md
