# Research Engine: Permissions

How permissions work for background sub-agents dispatched by :orchestrate.

## Required Rules

Add these to `~/.claude/settings.json` under `permissions.allow`:

```json
"Edit(/research/**)",
"Bash(*pplx-curl.sh*)",
"Bash(*yt-dlp*)"
```

## Why Each Rule Exists

### Edit(/research/**)

Auto-approves Edit operations to `<project-root>/research/` for foreground
agents and the main conversation. The :query skill (which runs in the main
conversation) uses the Write tool directly.

Note: this rule does NOT work for background agents. Background sub-agents
write files through `pplx-curl.sh --write` instead, which is covered by
the Bash rule below.

### Bash(*pplx-curl.sh*)

Auto-approves all Bash commands containing "pplx-curl.sh". This is the
primary permission for background sub-agents. All background file operations
go through pplx-curl.sh:

- `--research`: API calls + raw JSON saves
- `--write`: thread files, source files, cascade YAMLs
- `--fetch-pdf`: PDF downloads
- `--next-id`: research ID generation

### Bash(*yt-dlp*)

Auto-approves Bash commands containing "yt-dlp" (YouTube transcript
extraction). Used during deep dives to ingest video transcripts.

## Background Agent Write Limitation

**Background agents cannot use the Write or Edit tools** regardless of
settings.json allow rules. Tested 2026-04-03, Claude Code v2.1.91:

- `Edit(/research/**)`: foreground Write SUCCEEDED, background Write DENIED
- `Write(/research/**)`: background Write DENIED
- `Edit` (blanket, no path): background Write DENIED (after restart)
- `Bash(*pplx-curl.sh*)`: background Bash SUCCEEDED

Only Bash allow rules propagate to background agents. The research engine
works around this by routing all background file writes through
`pplx-curl.sh --write`, which is auto-approved via the Bash rule.

## Permission Evaluation Order

deny → ask → allow → permission mode

Allow rules are checked before the permission mode step. For foreground
agents, this works for all tool types. For background agents, only Bash
allow rules are evaluated.
