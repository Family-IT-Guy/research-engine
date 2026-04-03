# Research Engine: Permissions

How Write and Bash permissions work for background sub-agents dispatched by :orchestrate.

## Required Rules

Add these to `~/.claude/settings.json` under `permissions.allow`:

```json
"Edit(/research/**)",
"Bash(*pplx-curl.sh*)",
"Bash(*yt-dlp*)"
```

If you override the output directory (via extension file), update the Edit pattern to match. For example, `output_directory: research-output` requires `Edit(/research-output/**)`.

## Why Each Rule Exists

### Edit(/research/**)

Auto-approves Write/Edit operations to `<project-root>/research/` for ALL agents (foreground and background). The `Edit` rule covers both the Edit and Write tools per Claude Code docs: "Edit rules apply to all built-in tools that edit files."

Sub-agents write: thread files, raw API responses, source content, cascade YAMLs.

### Bash(*pplx-curl.sh*)

Auto-approves Bash commands containing "pplx-curl.sh" (the Perplexity API wrapper). This is the only Bash call in the execute workflow.

### Bash(*yt-dlp*)

Auto-approves Bash commands containing "yt-dlp" (YouTube transcript extraction). Used during deep dives to ingest video transcripts as primary sources.

## How It Works

### Permission Evaluation Order

deny → ask → allow → permission mode

Allow rules are checked BEFORE the permission mode step. Background agents auto-deny anything not pre-approved, but a matching allow rule counts as pre-approved.

### Path Patterns

| Pattern | Scope |
|---------|-------|
| `Edit(/research/**)` | Project-root-relative directory |
| `Edit(//absolute/path/**)` | Absolute path (double slash) |
| `Edit(~/home/path/**)` | Home-directory-relative |
| `Bash(*script-name*)` | Bash commands matching glob |

`/research/**` is project-root-relative (single leading slash). It matches `<whatever-project-you're-in>/research/**`. User-level settings apply globally across all projects.

### Background Agent Constraint

`permissionMode: acceptEdits` in custom agent definitions does NOT propagate to background agents (`run_in_background: true`). It works only for foreground sub-agents.

Background agents use a pre-launch approval + auto-deny mechanism that ignores the agent definition's `permissionMode`. The settings.json allow list bypasses this because allow rules are evaluated before the permission mode check.

**Evidence** (tested 2026-03-05, Claude Code v2.1.69):
- Foreground dispatch with `permissionMode: acceptEdits`: prompted user (did not auto-approve)
- Background dispatch with `permissionMode: acceptEdits`: Write denied
- Background dispatch with `Edit(/research/**)` allow rule: Write succeeded

## Adding New Permissions

If a future extension needs additional background agent permissions:

1. **Identify the tool and path** — what tool (Write, Edit, Bash) and what file paths does the background agent need access to?
2. **Add a scoped allow rule** to `~/.claude/settings.json` under `permissions.allow`. Use the narrowest scope possible.
3. **Test empirically** — dispatch a background sub-agent and verify the operation succeeds. Do NOT trust documentation alone.
4. **Document in your extension file** if it's a personal addition.
