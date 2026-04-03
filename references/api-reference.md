# Perplexity API Reference

## Endpoint

```
POST https://api.perplexity.ai/chat/completions
```

### Async Endpoint (for deep research)

```
POST https://api.perplexity.ai/async/chat/completions
```

Use the async endpoint when deep research may timeout (>60 seconds). Returns a task ID for polling.

**Important:** The async endpoint requires a `request` wrapper around the chat completion body. It is NOT the same format as the sync endpoint.

### Async Request Format

```json
{
  "request": {
    "model": "sonar-deep-research",
    "messages": [...],
    "web_search_options": {"search_context_size": "high"},
    "reasoning_effort": "high",
    "temperature": 0.2,
    "stream": false
  }
}
```

### Async Response (initial)

```json
{
  "id": "task-uuid-here",
  "model": "sonar-deep-research",
  "status": "CREATED",
  "created_at": 1771295807,
  "started_at": null,
  "completed_at": null,
  "failed_at": null,
  "error_message": null,
  "response": null
}
```

Status progression: `CREATED` -> `IN_PROGRESS` -> `COMPLETED` (or `FAILED`)

### Polling for Results

```
GET https://api.perplexity.ai/async/chat/completions/{task_id}
```

Poll until `status` is `COMPLETED` or `FAILED`. When completed, the `response` field contains the same structure as a sync response (choices, citations, search_results, usage).

### Async curl Example

```bash
# Submit async request (use plugin's pplx-curl.sh)
pplx-curl.sh "https://api.perplexity.ai/async/chat/completions" /tmp/async-submit.json '{"request":{"model":"sonar-deep-research","messages":[{"role":"user","content":"QUERY"}],"web_search_options":{"search_context_size":"high"},"reasoning_effort":"high","temperature":0.2,"stream":false}}'

# Poll for results (replace TASK_ID)
pplx-curl.sh --get "https://api.perplexity.ai/async/chat/completions/TASK_ID"
```

## Authentication

```bash
-H "Authorization: Bearer $PERPLEXITY_API_KEY"
```

API key location: `~/.claude/research-engine.env` (handled by pplx-curl.sh)

## Request Format

```json
{
  "model": "sonar-reasoning-pro",
  "messages": [
    {"role": "system", "content": "System prompt here"},
    {"role": "user", "content": "User query here"}
  ],
  "web_search_options": {"search_context_size": "high"},
  "return_related_questions": true,
  "temperature": 0.2,
  "stream": false
}
```

## Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| model | string | `sonar-reasoning-pro` or `sonar-deep-research` |
| messages | array | Array of message objects with role and content |

## Optional Parameters

### Our Defaults (Always Set)

These are set on every request by the skill:

| Parameter | Type | Value | Description |
|-----------|------|-------|-------------|
| search_context_size | string | `"high"` | Search breadth: "low", "medium", "high". **IMPORTANT:** Must be nested inside `web_search_options` object, NOT at the top level. Top-level placement is silently ignored (falls back to "low"). Pricing: $6/$10/$14 per 1K requests for low/med/high. |
| return_related_questions | boolean | `true` | Include follow-up question suggestions |
| temperature | float | `0.2` | Randomness (0-2). Lower = more focused |
| stream | boolean | `false` | Never stream (file-first architecture) |
| reasoning_effort | string | `"high"` | Deep-research only. Thoroughness: "low", "medium", "high" |

### Auto-Selected Per Query

The skill determines these during research planning:

| Parameter | Type | Description | Selection Logic |
|-----------|------|-------------|-----------------|
| search_mode | string | `"web"`, `"academic"`, `"sec"` | Studies/papers/scientific → academic. Companies/filings/SEC → sec. Everything else → web. |
| return_images | boolean | Include images in results | Visual topics → true. Technical/analytical → false. |

### Exposed During Research Plan

Suggested during research plan checkpoint, not set by default:

| Parameter | Type | Description |
|-----------|------|-------------|
| search_recency_filter | string | Time filter: "day", "week", "month", "year" |
| search_after_date_filter | string | Only results published after this date (MM/DD/YYYY) |
| search_before_date_filter | string | Only results published before this date (MM/DD/YYYY) |
| last_updated_after_filter | string | Only results updated after this date (MM/DD/YYYY) |
| last_updated_before_filter | string | Only results updated before this date (MM/DD/YYYY) |
| search_domain_filter | array | Limit to specific domains (max 20). Prefix with `-` to exclude. |

**Domain filter examples:**
```json
"search_domain_filter": ["docs.python.org", "github.com", "stackoverflow.com"]
```

```json
"search_domain_filter": ["-reddit.com", "-quora.com"]
```

### Never Set (Use Model Defaults)

| Parameter | Type | Default | Why Not Set |
|-----------|------|---------|-------------|
| max_tokens | integer | varies | Let model decide response length |
| top_p | float | 0.9 | Default is fine |
| top_k | integer | 0 | Default is fine |
| presence_penalty | float | 0 | Default is fine |
| frequency_penalty | float | 1 | Default is fine |
| disable_search | boolean | false | We always want search |
| enable_search_classifier | boolean | n/a | We always want search |

### Available (Document Only)

These exist in the API but have no defaults in our skill:

| Parameter | Type | Description |
|-----------|------|-------------|
| response_format | object | Structured output. `{"type": "json_schema", "json_schema": {...}}` or `{"type": "regex", "regex": {...}}`. Free text by default. |
| language_preference | string | Best-effort response language for sonar-reasoning-pro. |
| image_domain_filter | array | Filter image results to specific domains |
| image_format_filter | array | Filter image results by format |
| return_videos | boolean | Include video results |

**Structured output example:**
```json
{
  "response_format": {
    "type": "json_schema",
    "json_schema": {
      "name": "research_result",
      "strict": true,
      "schema": {
        "type": "object",
        "properties": {
          "summary": {"type": "string"},
          "key_findings": {"type": "array", "items": {"type": "string"}},
          "confidence": {"type": "number"}
        },
        "required": ["summary", "key_findings"]
      }
    }
  }
}
```

### Image Input

sonar-pro supports image input via base64 or URL in the messages array. NOT supported by sonar-deep-research.

```json
{
  "messages": [
    {
      "role": "user",
      "content": [
        {"type": "text", "text": "What is in this image?"},
        {"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}
      ]
    }
  ]
}
```

Note: We use sonar-reasoning-pro as our default, not sonar-pro. Image input is available but not part of our standard workflow.

## Response Format

```json
{
  "id": "unique-response-id",
  "model": "sonar-reasoning-pro",
  "created": 1703001234,
  "choices": [
    {
      "index": 0,
      "message": {
        "role": "assistant",
        "content": "Response text here..."
      },
      "finish_reason": "stop"
    }
  ],
  "citations": [
    "https://source.com/article"
  ],
  "search_results": [
    {
      "title": "Article Title",
      "url": "https://source.com/article",
      "date": "2026-01-15",
      "last_updated": "2026-02-10",
      "snippet": "Relevant excerpt from the source...",
      "source": "web"
    }
  ],
  "images": [
    {
      "image_url": "https://example.com/photo.jpg",
      "origin_url": "https://example.com/article",
      "height": 483,
      "width": 724,
      "title": "Image description"
    }
  ],
  "usage": {
    "prompt_tokens": 150,
    "completion_tokens": 892,
    "total_tokens": 1042,
    "search_context_size": "high",
    "cost": {
      "input_tokens_cost": 0.0003,
      "output_tokens_cost": 0.007136,
      "request_cost": 0.006,
      "total_cost": 0.013536
    }
  }
}
```

**Note:** `images` only present when `return_images: true`. Each image is a URL to a remote resource — images are NOT downloaded or stored locally. They appear in the raw JSON file saved to `raw/`, viewable by extracting URLs with `jq '.images[].image_url'`.

### Deep Research Response (additional fields)

```json
{
  "usage": {
    "prompt_tokens": 33,
    "completion_tokens": 11395,
    "total_tokens": 11428,
    "citation_tokens": 19028,
    "num_search_queries": 21,
    "reasoning_tokens": 193947,
    "cost": {
      "input_tokens_cost": 0.000066,
      "output_tokens_cost": 0.09116,
      "reasoning_tokens_cost": 0.581841,
      "citation_tokens_cost": 0.038056,
      "search_queries_cost": 0.105,
      "request_cost": 0.006,
      "total_cost": 0.816123
    }
  }
}
```

### Reasoning Traces (sonar-reasoning-pro)

Reasoning traces appear inside `<think>` tags within the response content:

```
<think>
Let me analyze the key factors...
1. First consideration: ...
2. Second consideration: ...
</think>

Based on my analysis, the key findings are...
```

## Complete curl Example

Use the plugin's `scripts/pplx-curl.sh` for all API calls. The script handles auth internally. Do NOT extract the key manually.

```bash
pplx-curl.sh "https://api.perplexity.ai/chat/completions" "$OUTPUT_FILE" '{"model":"sonar-reasoning-pro","messages":[{"role":"system","content":"You are a research assistant. Provide comprehensive, well-cited answers."},{"role":"user","content":"What are the key differences between PostgreSQL and MySQL for web applications?"}],"web_search_options":{"search_context_size":"high"},"search_mode":"web","return_related_questions":true,"return_images":false,"temperature":0.2,"stream":false}'
```

**Raw curl (for manual debugging only):**

```bash
curl -s "https://api.perplexity.ai/chat/completions" -H "Authorization: Bearer $PERPLEXITY_API_KEY" -H "Content-Type: application/json" -d '{"model":"sonar-reasoning-pro","messages":[{"role":"system","content":"You are a research assistant. Provide comprehensive, well-cited answers."},{"role":"user","content":"What are the key differences between PostgreSQL and MySQL for web applications?"}],"web_search_options":{"search_context_size":"high"},"search_mode":"web","return_related_questions":true,"return_images":false,"temperature":0.2,"stream":false}' | jq '.' > "$OUTPUT_FILE"
```

## Parsing Response with jq

Extract content:
```bash
| jq -r '.choices[0].message.content'
```

Extract search results:
```bash
| jq '.search_results[] | {title, url, date}'
```

Extract cost:
```bash
| jq '.usage.cost'
```

Full parsing:
```bash
curl -s ... | jq '{
  content: .choices[0].message.content,
  sources: [.search_results[] | {title, url, date, source}],
  model: .model,
  tokens: .usage.total_tokens,
  cost: .usage.cost.total_cost
}'
```

**Note:** The API returns both `citations` (legacy, array of URLs) and `search_results` (rich objects with title/url/date/snippet/source). Always use `search_results` for extraction.

## Error Handling

Common errors:

| Status | Meaning | Action |
|--------|---------|--------|
| 400 | Bad request | Check payload format |
| 401 | Unauthorized | Check API key |
| 429 | Rate limited | Wait and retry |
| 500 | Server error | Retry after delay |

**Error response format:**
```json
{
  "error": {
    "message": "Invalid model 'bad-model'. Permitted models can be found in the documentation.",
    "type": "invalid_model",
    "code": 400
  }
}
```

Known error types: `invalid_model` (bad model name), `invalid_message` (empty/malformed messages), `bad_request` (general).

## Rate Limits

Rate limits depend on account tier. Check response headers:
- `X-RateLimit-Limit`
- `X-RateLimit-Remaining`
- `X-RateLimit-Reset`
