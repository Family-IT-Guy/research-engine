#!/usr/bin/env bash
# test-fetch-html.sh — Unit tests for slug_url, cache, and --fetch-html
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PPLX_SCRIPT="$SCRIPT_DIR/pplx-curl.sh"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Source helper functions from pplx-curl.sh without running main dispatcher
source "$PPLX_SCRIPT" --source-only

# --- Test framework ---
FAIL_COUNT=0
PASS_COUNT=0
assert_eq() {
  if [[ "$1" == "$2" ]]; then
    echo "  PASS: $3"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $3"
    echo "    expected: $2"
    echo "    actual:   $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}
assert_ne() {
  if [[ "$1" != "$2" ]]; then
    echo "  PASS: $3"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $3 (values should differ)"
    echo "    both: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}
assert_match() {
  if echo "$1" | grep -qE "$2"; then
    echo "  PASS: $3"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "  FAIL: $3"
    echo "    value:   $1"
    echo "    pattern: $2"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

echo "=== slug_url tests ==="

# 1. Determinism: same URL = same slug
SLUG1=$(slug_url "https://example.com/page?q=1")
SLUG2=$(slug_url "https://example.com/page?q=1")
assert_eq "$SLUG1" "$SLUG2" "slug_url determinism (same URL = same slug)"

# 2. Uniqueness: different URLs = different slugs
SLUG_A=$(slug_url "https://example.com/page-a")
SLUG_B=$(slug_url "https://example.com/page-b")
assert_ne "$SLUG_A" "$SLUG_B" "slug_url uniqueness (different URLs = different slugs)"

# 3. Format: starts with domain
SLUG_FMT=$(slug_url "https://www.mayo-clinic.org/diseases/cancer")
assert_match "$SLUG_FMT" "^www_mayo_clinic_org_" "slug_url format starts with domain"

# 4. Path truncation: path component <= 40 chars
SLUG_LONG=$(slug_url "https://example.com/this-is-a-very-long-path-that-should-be-truncated-at-forty-characters-exactly")
# We know the domain is "example_com". Extract the path by removing known prefix and hash suffix.
DOMAIN_PART="example_com"
HASH_PART=$(echo "$SLUG_LONG" | grep -oE '[a-f0-9]{8}$')
PATH_PART="${SLUG_LONG#${DOMAIN_PART}_}"
PATH_PART="${PATH_PART%_${HASH_PART}}"
PATH_LEN=${#PATH_PART}
if [[ $PATH_LEN -le 40 ]]; then
  echo "  PASS: slug_url path truncation ($PATH_LEN <= 40)"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: slug_url path truncation ($PATH_LEN > 40)"
  echo "    path part: $PATH_PART"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 5. Empty path: URL with no path
SLUG_ROOT=$(slug_url "https://example.com")
assert_match "$SLUG_ROOT" "^example_com__[a-f0-9]{8}$" "slug_url handles root URL (no path)"

echo ""
echo "=== cache_read / cache_write tests ==="

CACHE_DIR="$TMPDIR_TEST/cache"
mkdir -p "$CACHE_DIR"

# 6. cache_read returns non-zero on miss
set +e
cache_read "$CACHE_DIR" "https://example.com/not-cached" >/dev/null 2>&1
MISS_CODE=$?
set -e
assert_eq "$MISS_CODE" "1" "cache_read returns non-zero on miss"

# 7. Create a cached file, then cache_read finds it via filesystem glob
TEST_URL="https://example.com/cached-page"
TEST_SLUG=$(slug_url "$TEST_URL")
TEST_FILE="20260407_120000_${TEST_SLUG}.md"
echo "test content" > "$CACHE_DIR/$TEST_FILE"

set +e
HIT_PATH=$(cache_read "$CACHE_DIR" "$TEST_URL" 2>/dev/null)
HIT_CODE=$?
set -e
assert_eq "$HIT_CODE" "0" "cache_read returns 0 on hit"
assert_match "$HIT_PATH" "$TEST_SLUG" "cache_read returns path containing slug"

# 8. cache_write creates JSON index
cache_write "$CACHE_DIR" "$TEST_URL" "$TEST_FILE" "Test Page" "text/html"
if [[ -f "$CACHE_DIR/.cache.json" ]]; then
  echo "  PASS: cache_write creates .cache.json"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: cache_write did not create .cache.json"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 9. cache_write JSON has correct structure
if command -v jq &>/dev/null; then
  CACHED_ENTRY=$(jq -r --arg url "$TEST_URL" '.[$url].path' "$CACHE_DIR/.cache.json" 2>/dev/null)
  assert_eq "$CACHED_ENTRY" "$TEST_FILE" "cache_write JSON has correct path"

  CACHED_CT=$(jq -r --arg url "$TEST_URL" '.[$url].content_type' "$CACHE_DIR/.cache.json" 2>/dev/null)
  assert_eq "$CACHED_CT" "text/html" "cache_write JSON has correct content_type"
else
  echo "  SKIP: jq not available for JSON structure tests"
fi

# 10. cache_read uses .cache.json for optimization (hit via JSON before glob)
CACHE_DIR2="$TMPDIR_TEST/cache2"
mkdir -p "$CACHE_DIR2"
TEST_URL2="https://example.com/json-cached"
TEST_FILE2="somefile.md"
echo "content" > "$CACHE_DIR2/$TEST_FILE2"
cache_write "$CACHE_DIR2" "$TEST_URL2" "$TEST_FILE2" "JSON Test" "text/html"
set +e
HIT2=$(cache_read "$CACHE_DIR2" "$TEST_URL2" 2>/dev/null)
HIT2_CODE=$?
set -e
assert_eq "$HIT2_CODE" "0" "cache_read finds file via .cache.json"

echo ""
echo "=== --fetch-html cache-hit test ==="

# 11. --fetch-html returns cached file on cache hit
FETCH_DIR="$TMPDIR_TEST/fetch"
mkdir -p "$FETCH_DIR"
FETCH_URL="https://example.com/already-fetched"
FETCH_SLUG=$(slug_url "$FETCH_URL")
FETCH_FILE="20260407_000000_${FETCH_SLUG}.md"
cat > "$FETCH_DIR/$FETCH_FILE" <<EOF
---
source_url: "$FETCH_URL"
title: "Already Fetched"
fetched_at: "2026-04-07T00:00:00Z"
content_type: "text/html"
---
Already fetched content.
EOF

set +e
FETCH_OUTPUT=$("$PPLX_SCRIPT" --fetch-html "$FETCH_URL" "$FETCH_DIR" 2>&1)
FETCH_CODE=$?
set -e
assert_eq "$FETCH_CODE" "0" "--fetch-html exits 0 on cache hit"
if echo "$FETCH_OUTPUT" | grep -q "LOCAL_PATH="; then
  echo "  PASS: --fetch-html outputs LOCAL_PATH on cache hit"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: --fetch-html missing LOCAL_PATH on cache hit"
  echo "    output: $FETCH_OUTPUT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi
if echo "$FETCH_OUTPUT" | grep -q "Cache hit"; then
  echo "  PASS: --fetch-html reports cache hit"
  PASS_COUNT=$((PASS_COUNT + 1))
else
  echo "  FAIL: --fetch-html does not report cache hit"
  echo "    output: $FETCH_OUTPUT"
  FAIL_COUNT=$((FAIL_COUNT + 1))
fi

echo ""
echo "=== --fetch-html playwright-cli test ==="

# 12. --fetch-html with playwright-cli (SKIP if not installed)
if command -v playwright-cli &>/dev/null; then
  LIVE_DIR="$TMPDIR_TEST/live"
  mkdir -p "$LIVE_DIR"
  set +e
  LIVE_OUTPUT=$("$PPLX_SCRIPT" --fetch-html "https://example.com" "$LIVE_DIR" 2>&1)
  LIVE_CODE=$?
  set -e
  if [[ $LIVE_CODE -eq 0 ]]; then
    echo "  PASS: --fetch-html fetches via playwright-cli"
    PASS_COUNT=$((PASS_COUNT + 1))
    if echo "$LIVE_OUTPUT" | grep -q "LOCAL_PATH="; then
      echo "  PASS: --fetch-html outputs LOCAL_PATH after fetch"
      PASS_COUNT=$((PASS_COUNT + 1))
    else
      echo "  FAIL: --fetch-html missing LOCAL_PATH after fetch"
      FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
  else
    echo "  FAIL: --fetch-html exit code $LIVE_CODE (expected 0)"
    echo "    output: $LIVE_OUTPUT"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
else
  echo "  SKIP: playwright-cli not installed (test 12)"
fi

echo ""
echo "=== Results ==="
echo "PASS: $PASS_COUNT"
echo "FAIL: $FAIL_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
echo "All tests passed."
