# Changelog

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
