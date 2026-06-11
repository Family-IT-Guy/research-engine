# Changelog

## 2.0.0 — 2026-06-11

### Changed — deep tier re-engined (Agent API + verification pass)

- **Deep dives now run on Perplexity's Agent API** (`POST /v1/agent`) with a
  frozen copy of the `deep-research` preset config
  (`references/agent-api-frozen-deep-research.json`, captured 2026-06-11) so
  Perplexity cannot change the engine underneath us. The hosted agent does
  retrieval and source reading; the sub-agent is now a verification layer:
  spot-verify 5+ load-bearing cited claims, entity hygiene, completeness audit,
  at most one supplementary sonar-pro call, corrections recorded in the thread
  file. Flow validated in a 20-run blind-graded head-to-head (2026-06-11):
  96.7% citation precision, half the cost and ~2x the speed of the 1.x deep dive.
- **Quick tier unchanged** (sonar-reasoning-pro single call) plus documented
  recovery for the API-side empty-completion bug: retry once, then switch to
  sonar-pro.
- `pplx-curl.sh --agent` mode added: posts to /v1/agent, saves raw JSON +
  `.content.md` + `.sources.md`, citation gate, empty-output gate, cost line.

### Removed

- **`--fetch-html` (playwright) and the wave-pattern source-reading machinery.**
  The shared playwright session collided across parallel research agents
  (three independent cross-contamination incidents, 2026-06-11) and was the
  source of all operational failures in eval. Verification fetching uses
  WebFetch/chawan/curl; PDFs still via `--fetch-pdf` (plain curl, kept).
- `scripts/test-fetch-html.sh`.

### Rollback

Tag `v1.2.2-pre-switch` / branch `pre-agent-api-1.2.2`; tarballs in
`~/.claude/plugins/local/research-engine-*-20260611.tar.gz`.


## 1.2.0 — 2026-04-10

### Fixed

- **Primary source HTML fetching in background sub-agents.** Sub-agents could not read HTML primary sources because WebFetch does not propagate to the background sub-agent sandbox. Research output silently degraded to Perplexity summaries only. Fixed by adding `pplx-curl.sh --fetch-html` which wraps playwright-cli for JS-rendered page fetching.

### Added

- `pplx-curl.sh --fetch-html <URL> [output_dir] [--browser=firefox|chromium|webkit]` — fetches web pages via playwright-cli with JavaScript rendering. Results cached to `research/sources/` by URL slug. Default browser: firefox (Chromium gets 403'd by medical journal sites).
- URL slug helper (`slug_url`) and cache system (filesystem glob + JSON index via jq) in pplx-curl.sh.
- Test harness at `scripts/test-fetch-html.sh`.
- Paywall detection guidance in execute workflow.
- Browser fallback chain: sub-agent tries firefox → chromium → webkit based on fetch results.

### Changed

- **Thin SKILL.md entrypoints.** All 4 skill files (orchestrate, execute, query, retrieve) reduced to 3-5 line pointers to references/ files. Users no longer see 100-490 lines of workflow documentation when a skill loads.
- Removed WebFetch from research-executor agent tools list (never worked in sub-agent sandbox).
- Execute workflow: WebFetch replaced with --fetch-html throughout (HTML URLs section, wave pattern, fallback section).

### Prerequisites

- **playwright-cli** (CLI + skill) is now required for deep-dive research HTML fetching.
- **jq** is now required for cache index operations.
