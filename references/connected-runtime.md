# How to run Research Engine with connected tools

Read methodology.md and follow it. This adapter requires no shell, local files, local agents, or Claude extension file.

## Establish capabilities

Discover the connected Perplexity tools and their actual schemas. Prefer perplexity_search for the search-and-read workflow. perplexity_ask, perplexity_research, and perplexity_reason can provide a draft; verify consequential claims against the original sources before presenting them as established.

Confirm a source-reading capability separately by opening a public primary-source URL. Search success does not prove that source reading works. If reading is unavailable, label the result search-only and name the unverified claims; do not claim the full research workflow succeeded.

If Perplexity is not connected, use the setup skill. Do not silently substitute another provider. If authentication or billing fails, report the service's error without exposing secrets; retry transient failures once, and stop retrying authentication failures.

## Research and retain

Execute the shared method in the current conversation. Delegation is optional and only used when the host supports it. Existing research can be read from a connected record system; local research folders are not required.

When Health Charted is connected and the user is working on a person's health, read that person's research notes before researching. At completion, load its research-capture guide and use its record schema to save relevant findings, source URLs, uncertainty, unresolved questions, and links to the relevant conditions or treatments. Reuse the existing note's ID when updating a topic. Read the saved note back. Research Engine does not itself store patient records.

Return an honest receipt: what was researched, which sources were read, what remains uncertain, and whether and where the findings were saved. An unavailable store does not prevent research, but persistence remains incomplete.
