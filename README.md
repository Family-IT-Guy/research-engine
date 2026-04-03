# Research Engine

Cited web research for Claude Code. Ask a question, get structured findings with sources, costs tracked, everything saved to files.

**License:** MIT

## What it does

You ask Claude to research something. Instead of searching the web and giving you a summary it might have made up, the research engine calls the Perplexity Sonar API, saves the complete response, reads the primary sources, follows interesting leads, and writes a structured thread file with citations, confidence assessments, and cost tracking.

Every finding traces back to a source. Every source is saved. If something looks incomplete, the system generates follow-up research requests and asks if you want to keep digging.

## Setup

1. **Install the plugin**

   ```bash
   claude mcp add-plugin research-engine --local /path/to/research-engine
   ```

   Or clone this repo and point Claude Code at it.

2. **Get a Perplexity API key**

   Sign up at [perplexity.ai](https://perplexity.ai), go to API settings, generate a key.

   Set it as an environment variable:
   ```bash
   export PERPLEXITY_API_KEY="pplx-your-key-here"
   ```

   Or create `.env` in the plugin root:
   ```
   PERPLEXITY_API_KEY=pplx-your-key-here
   ```

3. **Add permissions for background research**

   The research engine dispatches background sub-agents that need pre-approved permissions. Add to `~/.claude/settings.json`:

   ```json
   {
     "permissions": {
       "allow": [
         "Edit(/research/**)",
         "Bash(*pplx-curl.sh*)",
         "Bash(*yt-dlp*)"
       ]
     }
   }
   ```

4. **Optional: install yt-dlp** for YouTube transcript extraction during deep dives

   ```bash
   brew install yt-dlp
   ```

## Usage

**Research a topic:**
> "Research the current state of CRISPR gene therapy for sickle cell disease"

The system extracts topics, checks what you've already researched, presents a plan, and dispatches background agents when you approve.

**Quick inline question:**
> "Quick question: what's the half-life of metformin?"

Single query, answered in the conversation, saved to a thread file.

**Check existing research:**
> "What do we know about magnesium supplementation?"

Searches your local research files and tells you what's covered, what's stale, and what's missing.

## How it works

Four skills:

| Skill | What it does |
|-------|-------------|
| **orchestrate** | Multi-topic sessions. Extracts topics, checks coverage, dispatches background agents, handles cascades. |
| **execute** | Internal. Runs inside background agents. Calls the API, reads sources, writes thread files. |
| **query** | Single inline question. Runs in the main conversation. |
| **retrieve** | Searches existing research. Assesses coverage. |

### Research depth

- **Quick scan**: single API call, Perplexity synthesis only. For factual lookups. ~$0.01-0.05.
- **Deep dive**: API call + primary source reading + wave pattern + cascade generation. For anything that matters. ~$0.10-5.00+.

### The researcher

The execute skill isn't just an API wrapper. It reads the sources Perplexity cited, checks whether they actually support the claims, follows leads from those sources, grades evidence quality, and generates cascade requests when it finds gaps worth chasing. Skeptical by default. Documents what's unknown as explicitly as what's known.

## Output

Research files land in `./research/` in your project:

```
research/
├── raw/                            # Complete API responses (JSON)
├── sources/                        # Fetched primary sources (deep dives)
├── cascades/                       # Follow-up research requests
└── topic-slug-2026-04-03.md        # Thread file with findings + citations
```

Thread files have YAML frontmatter with research ID, cost, model, depth, and source count. The body has synthesized findings, numbered sources, confidence assessments, and open questions.

## Extending

Create `~/.claude/research-engine.md` to add:

- **Coverage Sources**: additional systems to search when checking what's already known (databases, vector stores, note systems)
- **Post-Research Hooks**: actions to run after research completes (annotate source documents, update logs)
- **Settings**: override output directory, YouTube tool, legacy search paths

The extension file is optional. The base plugin works without it.

## Models and pricing

| Model | Use | Cost |
|-------|-----|------|
| sonar-reasoning-pro | All queries (default) | ~$0.01-0.05 per query |
| sonar-deep-research | Exhaustive research | ~$0.50-3.00 per query |

See `references/models.md` for full pricing breakdown and selection guidance.

## Requirements

- Claude Code (CLI or Desktop)
- Perplexity API key ($)
- Optional: yt-dlp (free, for YouTube transcripts)
