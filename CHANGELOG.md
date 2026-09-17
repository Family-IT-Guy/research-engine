# Changelog

## 2.1.0 — 2026-09-16

### Added

- **One research method for every runtime.** `references/methodology.md` holds the
  method both the local Claude runtime and a connected host follow: identify the
  question, plan searches that could disconfirm the leading explanation, search,
  open the ORIGINAL sources, assess each material claim, synthesize with
  resolvable citations, and retain the work only after a read-back succeeds.
- **`references/connected-runtime.md`** — running the same method on a host that
  offers connected Perplexity tools and a source reader, with no shell, no local
  files and no sub-agents. Covers handing findings to a connected record system
  and reading them back in a later conversation.
- **`skills/setup`** — connecting Perplexity through the host's own OAuth flow
  where it exists, or the user's own API key entered in the host's credential
  settings. Never in chat, a document, a manifest or a transcript. Search and
  source reading are proven separately, because search succeeding does not show
  that reading a source works.
- **`scripts/build-chatgpt-skill.py`** — builds a single-skill archive for a
  connected host FROM the canonical references, so there is no second copy of the
  method to drift. Local scripts and Claude-runtime instructions are excluded.
- **`.codex-plugin/plugin.json`** — Codex/connected-host manifest.

### Changed

- **Evidence is assessed per claim, not ranked by study category.** The five-row
  evidence-tier table is gone. A claim is assessed on methodology rigor,
  independent replication, mechanism support, conflicts of interest, and
  generalizability to the question, and the thin axis is named. Study type is
  recorded as description. A small unblinded RCT can be weaker than a large,
  well-controlled cohort, and the tier table said otherwise.
- Confidence lines in the report template now carry their reason, so a label can
  be checked instead of taken.
- Both manifests carry 2.1.0. Their descriptions differ on purpose: the Claude
  manifest describes the local runtime, the Codex manifest the connected one.
- Quick scans and single queries now open the source behind each material claim
  before presenting it as established; untraced claims are labelled search
  synthesis. Two models agreeing is no longer treated as a confidence grade.
- The orchestrate skill picks its adapter in a fixed order: the full Claude Code
  runtime, then connected Perplexity tools, then setup. A shell alone no longer
  selects the local adapter.

## 2.0.3 — 2026-07-14

### Fixed

- Skill context pointers now resolve. The four skills (orchestrate, execute,
  query, retrieve) and the internal cross-references inside `references/` pointed
  to `references/X.md` as if resolved from the plugin root, but a skill loads with
  its base directory at `skills/<name>/`, so the workflow docs never loaded.
  Pointers now resolve against the reader's actual base: each SKILL.md uses
  `../../references/<workflow>.md`; internal sibling pointers inside `references/`
  use bare filenames. README.md/CHANGELOG.md unchanged (already root-relative).



## 2.0.1 — 2026-06-13

### Fixed

- Skill descriptions and README opener no longer say deep research runs "via
  Perplexity Sonar API" — corrected to reflect 2.0.0: Claude-led deep dives
  over the Search API, quick Sonar scans. Trigger/description text only; no
  behavior change.


## 2.0.0 — 2026-06-11

### Changed — deep tier re-architected: Claude-led research on raw search

- **Deep dives are now Claude-led.** The executing Claude (user's Max
  subscription — strongest model, zero marginal token cost) plans query
  fan-outs, reads primary sources, synthesizes, and grounds every claim in a
  fetched source. Perplexity supplies retrieval only: the Search API
  (`pplx-curl.sh --search`, raw ranked results, ~$0.005/query, no token
  charges). Decision: Ben 2026-06-11 (strategic log) — quality evidence from a
  50-run blind-graded eval favored Claude-heavy architecture; quota not a
  constraint.
- **Hosted alternate kept:** `pplx-curl.sh --agent` calls the Agent API
  `deep-research` preset by name (inherits Perplexity's improvements) for
  cases where a fast hosted draft is explicitly preferred; its draft gets the
  verification pass (claim spot-checks, entity hygiene, completeness audit).
  `references/agent-api-frozen-deep-research.json` (captured 2026-06-11)
  documents the preset config of record and can pin old behavior if a preset
  update degrades.
- **Quick tier unchanged** (sonar-reasoning-pro single call) plus documented
  recovery for the API-side empty-completion bug: retry once, then switch to
  sonar-pro.
- Thread frontmatter now records `engine` and `engine_model` per run.

### Removed

- **`--fetch-html` (playwright) and its test script.** The shared playwright
  session collided across parallel research agents (three independent
  cross-contamination incidents during eval) and caused every 1.x operational
  failure. Fetching now uses WebFetch/chawan/curl; PDFs via `--fetch-pdf`
  (plain curl, kept).

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
