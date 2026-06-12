#!/usr/bin/env bash
# pplx-curl.sh — Perplexity API wrapper with internal auth + research utilities
#
# Auth is handled here so callers never touch the API key directly.
# This avoids fragile Bash permission patterns with nested $() expressions.
#
# Usage:
#   POST:       pplx-curl.sh <url> <output_file> <json_payload>
#   GET:        pplx-curl.sh --get <url> [output_file]
#   RESEARCH:   pplx-curl.sh --research <topic_slug> <json_payload> [research_dir]
#   AGENT:      pplx-curl.sh --agent <topic_slug> <json_payload> [research_dir]
#   FETCH-PDF:  pplx-curl.sh --fetch-pdf <url> [output_dir]
#   NEXT-ID:    pplx-curl.sh --next-id [research_dir] [count]
#   WRITE:      pplx-curl.sh --write <filepath>  (reads content from stdin)
#
# RESEARCH mode handles directory creation, timestamp generation, and filename
# construction internally. This allows sub-agents to make a SINGLE Bash call
# instead of multiple calls (which trigger permission denial and Bash abandonment).
# The output file path is printed as the last line: OUTPUT_PATH=<path>
#
# FETCH-PDF mode downloads a remote PDF to a local file so the Read tool can
# parse it. No API key needed. Validates the download is actually a PDF.
# Output: LOCAL_PATH=<path> (last line) or exits non-zero with error details.
#
# AGENT mode posts to the Agent API (/v1/agent) with the same file conventions
# as RESEARCH mode, plus a .sources.md extract and an empty-output gate.
# Verification-pass fetching of cited URLs uses the WebFetch tool or chawan,
# NOT this script — the playwright fetch path was removed in 2.0.0 (shared
# browser sessions collided across parallel agents).
#
# GET mode defaults to stdout if no output_file given.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- slug_url: deterministic filename slug from a URL ---
# Produces: {domain}_{path-slug}_{hash8}
# domain: strip scheme, replace non-alphanum with underscore
# path: strip query/fragment, replace non-alphanum with hyphens, truncate to 40 chars
# hash8: first 8 chars of sha256(full URL)
slug_url() {
  local url="$1"
  # Strip scheme
  local domain="${url#*://}"
  domain="${domain%%/*}"
  domain=$(echo "$domain" | sed 's/[^a-zA-Z0-9]/_/g')

  # Path: strip query and fragment, then slug
  local no_scheme="${url#*://}"
  local path=""
  if [[ "$no_scheme" == *"/"* ]]; then
    path="${no_scheme#*/}"    # everything after first /
    path="${path%%\?*}"       # strip query string
    path="${path%%#*}"        # strip fragment
    path=$(echo "$path" | sed 's/[^a-zA-Z0-9]/-/g' | cut -c1-40)
  fi

  # Hash: first 8 chars of sha256
  local hash8
  hash8=$(printf '%s' "$url" | shasum -a 256 | cut -c1-8)

  # Assemble (handle empty path)
  if [[ -n "$path" ]]; then
    echo "${domain}_${path}_${hash8}"
  else
    echo "${domain}__${hash8}"
  fi
}

# --- Cache system ---
# cache_read <cache_dir> <url>
#   Checks for files matching the URL slug in cache_dir.
#   Prints path and exits 0 on hit, exits 1 on miss.
#   .cache.json is checked first as optimization; filesystem glob is source of truth.
cache_read() {
  local cache_dir="$1"
  local url="$2"
  local slug
  slug=$(slug_url "$url")

  # Optimization: check .cache.json first if jq available
  if command -v jq &>/dev/null && [[ -f "$cache_dir/.cache.json" ]]; then
    local cached_path
    cached_path=$(jq -r --arg url "$url" '.[$url].path // empty' "$cache_dir/.cache.json" 2>/dev/null || true)
    if [[ -n "$cached_path" && -f "$cache_dir/$cached_path" ]]; then
      echo "$cache_dir/$cached_path"
      return 0
    fi
  fi

  # Source of truth: filesystem glob
  local match
  match=$(find "$cache_dir" -maxdepth 1 -name "*${slug}*" -type f 2>/dev/null | head -1)
  if [[ -n "$match" ]]; then
    echo "$match"
    return 0
  fi

  return 1
}

# cache_write <cache_dir> <url> <relative_filename> <title> <content_type>
#   Adds/updates an entry in .cache.json. If jq isn't available, skips silently.
cache_write() {
  local cache_dir="$1"
  local url="$2"
  local rel_filename="$3"
  local title="$4"
  local content_type="$5"

  # Without jq, skip silently (cache still works via filesystem glob)
  if ! command -v jq &>/dev/null; then
    return 0
  fi

  local cache_file="$cache_dir/.cache.json"
  local fetched_at
  fetched_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  # Read existing or start fresh
  local existing="{}"
  if [[ -f "$cache_file" ]]; then
    existing=$(jq '.' "$cache_file" 2>/dev/null || echo "{}")
    # If parse failed, delete and start fresh
    if [[ "$existing" == "{}" && -s "$cache_file" ]]; then
      rm -f "$cache_file"
    fi
  fi

  # Update entry
  echo "$existing" | jq --arg url "$url" \
    --arg path "$rel_filename" \
    --arg fetched "$fetched_at" \
    --arg title "$title" \
    --arg ct "$content_type" \
    '.[$url] = {"path": $path, "fetched_at": $fetched, "title": $title, "content_type": $ct}' \
    > "$cache_file"
}

# --- --source-only: let test harnesses source helper functions without running main ---
if [[ "${1:-}" == "--source-only" ]]; then
  return 0 2>/dev/null || exit 0
fi

# --write writes content from stdin to a file (for background sub-agents
# that can't use the Write tool directly)
if [[ "${1:-}" == "--write" ]]; then
  OUTPUT_FILE="$2"
  mkdir -p "$(dirname "$OUTPUT_FILE")"
  cat > "$OUTPUT_FILE"
  echo "Written: $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | tr -d ' ') bytes)"
  exit 0
fi

# --next-id generates the next sequential research ID for today
if [[ "${1:-}" == "--next-id" ]]; then
  RESEARCH_DIR="${2:-./research}"
  COUNT="${3:-1}"
  TODAY_ID=$(date +%Y-%m%d)
  TODAY_FILE=$(date +%Y-%m-%d)
  EXISTING=$(find "$RESEARCH_DIR" -maxdepth 1 -name "*-${TODAY_FILE}.md" 2>/dev/null | wc -l | tr -d ' ')
  for ((i=1; i<=COUNT; i++)); do
    NEXT=$(printf "%03d" $((EXISTING + i)))
    echo "RE-${TODAY_ID}-${NEXT}"
  done
  exit 0
fi

# --fetch-pdf doesn't need the API key, handle it before key extraction
if [[ "${1:-}" == "--fetch-pdf" ]]; then
  shift
  URL="$1"
  OUTPUT_DIR="${2:-./research/sources}"

  mkdir -p "$OUTPUT_DIR"
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)

  # Derive filename from URL: take last path segment, replace non-alphanumeric
  URL_SLUG=$(echo "$URL" | sed 's|.*/||' | sed 's/[^a-zA-Z0-9._-]/_/g')
  OUTPUT_FILE="$OUTPUT_DIR/${TIMESTAMP}_${URL_SLUG}"

  # Download with browser-like User-Agent (some sites block bare curl)
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "$OUTPUT_FILE" \
    -L --max-redirs 5 --max-time 30 \
    -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
    -H "Accept: application/pdf,*/*" \
    "$URL")

  if [[ "$HTTP_CODE" -ge 400 ]]; then
    echo "ERROR: HTTP $HTTP_CODE fetching $URL" >&2
    rm -f "$OUTPUT_FILE"
    exit 1
  fi

  # Verify we got a PDF (check magic bytes), not an HTML error page
  FILE_HEAD=$(head -c 5 "$OUTPUT_FILE" 2>/dev/null || echo "")
  if [[ "$FILE_HEAD" != "%PDF-" ]]; then
    CONTENT_TYPE=$(file -b --mime-type "$OUTPUT_FILE" 2>/dev/null || echo "unknown")
    echo "ERROR: Downloaded file is not a PDF (got $CONTENT_TYPE)" >&2
    echo "URL: $URL" >&2
    # Keep the file for debugging but report failure
    echo "SAVED_NON_PDF=$OUTPUT_FILE" >&2
    exit 2
  fi

  FILE_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
  echo "Downloaded: $OUTPUT_FILE ($FILE_SIZE bytes)"
  echo "LOCAL_PATH=$OUTPUT_FILE"
  exit 0
fi

# --- API key ---
PPLX_KEY=""
if [[ -f "$HOME/.claude/research-engine.env" ]]; then
  PPLX_KEY=$(grep '^PERPLEXITY_API_KEY' "$HOME/.claude/research-engine.env" | sed 's/^PERPLEXITY_API_KEY=//' | tr -d '"' | tr -d "'")
fi

if [[ -z "$PPLX_KEY" ]]; then
  echo "ERROR: No Perplexity API key found." >&2
  echo "Create ~/.claude/research-engine.env with: PERPLEXITY_API_KEY=pplx-your-key-here" >&2
  exit 1
fi

if [[ "${1:-}" == "--research" ]]; then
  shift
  TOPIC_SLUG="$1"
  PAYLOAD="$2"
  RESEARCH_DIR="${3:-./research}"

  mkdir -p "$RESEARCH_DIR/raw" "$RESEARCH_DIR/sources" "$RESEARCH_DIR/cascades"
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  OUTPUT_FILE="$RESEARCH_DIR/raw/${TIMESTAMP}_${TOPIC_SLUG}.json"

  HTTP_CODE=$(curl -s -w "%{http_code}" -o "$OUTPUT_FILE" \
    "https://api.perplexity.ai/chat/completions" \
    -H "Authorization: Bearer ${PPLX_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  if [[ "$HTTP_CODE" -ge 400 ]]; then
    echo "ERROR: API returned HTTP $HTTP_CODE" >&2
    cat "$OUTPUT_FILE" >&2
    exit 1
  fi

  # Format JSON if jq available
  if command -v jq &>/dev/null; then
    TMP=$(mktemp)
    if jq '.' "$OUTPUT_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$OUTPUT_FILE"
    else
      rm -f "$TMP"
    fi
  fi

  # Extract content to readable markdown file
  CONTENT_FILE="${OUTPUT_FILE%.json}.content.md"
  if command -v jq &>/dev/null; then
    jq -r '.choices[0].message.content // empty' "$OUTPUT_FILE" > "$CONTENT_FILE" 2>/dev/null
  fi

  # Citation-count gate: reject training-data-only responses (0 live web citations)
  if command -v jq &>/dev/null; then
    CITE_COUNT=$(jq '.search_results | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
    if [[ "$CITE_COUNT" == "null" ]]; then CITE_COUNT=0; fi
    if [[ "$CITE_COUNT" -eq 0 ]]; then
      echo "REJECTED: 0 live citations in search_results. Response is training-data only." >&2
      echo "Raw JSON preserved at: $OUTPUT_FILE (for inspection)" >&2
      echo "Content file removed: $CONTENT_FILE" >&2
      rm -f "$CONTENT_FILE"
      echo "CITATION_CHECK_FAILED=true"
      echo "OUTPUT_PATH=$OUTPUT_FILE"
      exit 1
    elif [[ "$CITE_COUNT" -lt 5 ]]; then
      echo "WARNING: Only $CITE_COUNT citations. Thin grounding — flag in thread file." >&2
    fi
    echo "Citations: $CITE_COUNT"
  fi

  echo "Saved: $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | tr -d ' ') bytes)"
  if [[ -s "$CONTENT_FILE" ]]; then
    echo "Content: $CONTENT_FILE ($(wc -c < "$CONTENT_FILE" | tr -d ' ') bytes)"
  fi
  echo "OUTPUT_PATH=$OUTPUT_FILE"

elif [[ "${1:-}" == "--agent" ]]; then
  # --agent posts to the Agent API (POST /v1/agent) and saves raw + content,
  # same file conventions as --research. Payload is built by the calling skill
  # (frozen deep-research config merged with the task input).
  shift
  TOPIC_SLUG="$1"
  PAYLOAD="$2"
  RESEARCH_DIR="${3:-./research}"

  mkdir -p "$RESEARCH_DIR/raw" "$RESEARCH_DIR/sources" "$RESEARCH_DIR/cascades"
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  OUTPUT_FILE="$RESEARCH_DIR/raw/${TIMESTAMP}_${TOPIC_SLUG}.json"

  HTTP_CODE=$(curl -s -w "%{http_code}" -o "$OUTPUT_FILE" \
    --max-time 1500 \
    "https://api.perplexity.ai/v1/agent" \
    -H "Authorization: Bearer ${PPLX_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  if [[ "$HTTP_CODE" -ge 400 ]]; then
    echo "ERROR: Agent API returned HTTP $HTTP_CODE" >&2
    cat "$OUTPUT_FILE" >&2
    exit 1
  fi

  if command -v jq &>/dev/null; then
    TMP=$(mktemp)
    if jq '.' "$OUTPUT_FILE" > "$TMP" 2>/dev/null; then
      mv "$TMP" "$OUTPUT_FILE"
    else
      rm -f "$TMP"
    fi
  fi

  CONTENT_FILE="${OUTPUT_FILE%.json}.content.md"
  if command -v jq &>/dev/null; then
    jq -r '[.output[]? | select(.type=="message") | .content[]? | select(.type=="output_text") | .text] | join("\n")' \
      "$OUTPUT_FILE" > "$CONTENT_FILE" 2>/dev/null

    # Sources extract: title + url per unique result, for the verification pass
    SOURCES_FILE="${OUTPUT_FILE%.json}.sources.md"
    jq -r '[.output[]? | select(.type=="search_results") | .results[]?] | unique_by(.url) | .[] | "- \(.title // "untitled") — \(.url)"' \
      "$OUTPUT_FILE" > "$SOURCES_FILE" 2>/dev/null

    CITE_COUNT=$(jq '[.output[]? | select(.type=="search_results") | .results[]?] | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
    [[ "$CITE_COUNT" == "null" ]] && CITE_COUNT=0
    COST=$(jq -r '.usage.cost.total_cost // "unknown"' "$OUTPUT_FILE" 2>/dev/null)

    # Empty-output gate: engine can exhaust its output budget on reasoning
    # (observed 2026-06-11 on wide-enumeration tasks) — citations present, text empty.
    CONTENT_BYTES=$(wc -c < "$CONTENT_FILE" | tr -d ' ')
    if [[ "$CONTENT_BYTES" -lt 200 ]]; then
      echo "EMPTY_OUTPUT=true (content ${CONTENT_BYTES} bytes; citations: $CITE_COUNT)" >&2
      echo "Raw preserved at: $OUTPUT_FILE — retry guidance in execution.md" >&2
      echo "OUTPUT_PATH=$OUTPUT_FILE"
      exit 1
    fi

    if [[ "$CITE_COUNT" -eq 0 ]]; then
      echo "REJECTED: 0 web citations in Agent API output. Response is training-data only." >&2
      rm -f "$CONTENT_FILE"
      echo "CITATION_CHECK_FAILED=true"
      echo "OUTPUT_PATH=$OUTPUT_FILE"
      exit 1
    fi
    echo "Citations: $CITE_COUNT"
    echo "Cost: $COST"
    echo "Sources: $SOURCES_FILE"
  fi

  echo "Saved: $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | tr -d ' ') bytes)"
  echo "Content: $CONTENT_FILE ($(wc -c < "$CONTENT_FILE" | tr -d ' ') bytes)"
  echo "OUTPUT_PATH=$OUTPUT_FILE"

elif [[ "${1:-}" == "--search" ]]; then
  # --search posts to the Search API (POST /search): raw ranked results, no
  # model, $5 per 1K requests. Used by the Claude-led deep-dive loop.
  # Usage: pplx-curl.sh --search <slug> '<json_payload>' [research_dir]
  # Payload example: {"query":"...", "max_results": 10}
  shift
  TOPIC_SLUG="$1"
  PAYLOAD="$2"
  RESEARCH_DIR="${3:-./research}"

  mkdir -p "$RESEARCH_DIR/raw"
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  OUTPUT_FILE="$RESEARCH_DIR/raw/${TIMESTAMP}_${TOPIC_SLUG}.search.json"

  HTTP_CODE=$(curl -s -w "%{http_code}" -o "$OUTPUT_FILE" \
    --max-time 60 \
    "https://api.perplexity.ai/search" \
    -H "Authorization: Bearer ${PPLX_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  if [[ "$HTTP_CODE" -ge 400 ]]; then
    echo "ERROR: Search API returned HTTP $HTTP_CODE" >&2
    cat "$OUTPUT_FILE" >&2
    exit 1
  fi

  if command -v jq &>/dev/null; then
    TMP=$(mktemp)
    jq '.' "$OUTPUT_FILE" > "$TMP" 2>/dev/null && mv "$TMP" "$OUTPUT_FILE" || rm -f "$TMP"
    RESULT_COUNT=$(jq '.results | length' "$OUTPUT_FILE" 2>/dev/null || echo 0)
    echo "Results: $RESULT_COUNT"
    jq -r '.results[]? | "- \(.title // "untitled") — \(.url) (\(.date // "n.d."))"' "$OUTPUT_FILE" 2>/dev/null | head -20
  fi
  echo "OUTPUT_PATH=$OUTPUT_FILE"

elif [[ "${1:-}" == "--get" ]]; then
  shift
  URL="$1"
  OUTPUT="${2:--}"
  if [[ "$OUTPUT" == "-" ]]; then
    curl -s "$URL" -H "Authorization: Bearer ${PPLX_KEY}" | jq '.'
  else
    curl -s "$URL" -H "Authorization: Bearer ${PPLX_KEY}" | jq '.' > "$OUTPUT"
    echo "Saved: $OUTPUT ($(wc -c < "$OUTPUT") bytes)"
  fi
else
  URL="$1"
  OUTPUT="$2"
  PAYLOAD="$3"
  curl -s "$URL" \
    -H "Authorization: Bearer ${PPLX_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" | jq '.' > "$OUTPUT"
  echo "Saved: $OUTPUT ($(wc -c < "$OUTPUT") bytes)"
fi
