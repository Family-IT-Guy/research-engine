---
name: research-engine:orchestrate
description: >-
  Deep web research over the Perplexity Search and Sonar APIs (Claude-led deep
  dives, quick Sonar scans) with cited sources, reasoning traces, and
  persistent research threads. ALWAYS use instead of WebSearch,
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

# Research Engine

Read `../../references/methodology.md` first.

Choose the adapter from the capabilities actually available, checking in this order and taking the first that holds:
1. This is Claude Code with the full local runtime — `$CLAUDE_PLUGIN_ROOT` is set, the installed Perplexity wrapper exists at `$CLAUDE_PLUGIN_ROOT/scripts/pplx-curl.sh`, and the Agent tool can start the `research-executor` agent: read `../../references/orchestration.md` and follow it. It keeps research threads on disk, so it stays the choice here even if a Perplexity connector is also present. A shell alone is not enough.
2. Otherwise, connected Perplexity tools are present in this conversation: read `../../references/connected-runtime.md` and follow it.
3. Neither holds: use `research-engine:setup` to connect Perplexity, and say research has not started.

Use the shared method on both paths. No provider or study category supplies a default evidence grade.
