# Research Engine: Permissions

How permissions work for background sub-agents dispatched by :orchestrate.

## Required Rules

Add these to `~/.claude/settings.json` under `permissions.allow`:

```json
"Edit(/research/**)",
"Write(/research/**)",
"Bash(*pplx-curl.sh*)",
"Bash(*yt-dlp*)"
```

Both `Edit` and `Write` rules are required. Despite documentation claiming
Edit rules cover Write, background agents need an explicit `Write` rule to
create new files. Tested 2026-04-03, Claude Code v2.1.91.

## Why Each Rule Exists

### Edit(/research/**) + Write(/research/**)

Auto-approves file operations to `<project-root>/research/` for background
sub-agents. `Edit` covers modifications to existing files. `Write` covers
creating new files (thread files, source content, cascade YAMLs).

### Bash(*pplx-curl.sh*)

Auto-approves Bash commands containing "pplx-curl.sh" (the Perplexity API
wrapper). This is the only Bash call in the execute workflow.

### Bash(*yt-dlp*)

Auto-approves Bash commands containing "yt-dlp" (YouTube transcript
extraction). Used during deep dives to ingest video transcripts as primary
sources.

## How It Works

### Permission Evaluation Order

deny → ask → allow → permission mode

Allow rules are checked BEFORE the permission mode step. Background agents
auto-deny anything not pre-approved, but a matching allow rule counts as
pre-approved.

### Path Patterns

| Pattern | Scope |
|---------|-------|
| `Edit(/research/**)` | Project-root-relative directory |
| `Write(/research/**)` | Project-root-relative directory |
| `Edit(//absolute/path/**)` | Absolute path (double slash) |
| `Bash(*script-name*)` | Bash commands matching glob |

`/research/**` is project-root-relative (single leading slash). It matches
`<whatever-project-you're-in>/research/**`. User-level settings apply
globally across all projects.

### Background Agent Permissions

`permissionMode: acceptEdits` in custom agent definitions does NOT propagate
to background agents (`run_in_background: true`). It works only for
foreground sub-agents.

Background agents use a pre-launch approval + auto-deny mechanism that
ignores the agent definition's `permissionMode`. The settings.json allow
list bypasses this because allow rules are evaluated before the permission
mode check.

**Tested 2026-04-03, Claude Code v2.1.91:**
- `Edit(/research/**)` alone: background Write DENIED
- `Edit(/research/**)` + `Write(/research/**)`: background Write SUCCEEDED
- `Bash(*pplx-curl.sh*)`: background Bash SUCCEEDED
- Foreground agents: Write SUCCEEDED with Edit rule alone
