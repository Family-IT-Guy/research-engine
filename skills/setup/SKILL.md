---
name: research-engine:setup
description: Set up and verify the Perplexity connection for Research Engine. Use when installing Research Engine, connecting Perplexity, or resolving an authentication failure.
---

# Set up Research Engine

1. Identify the host and discover available Perplexity tools. An installed skill is not proof of a connected search service.
2. For a connected client, consult the current official Perplexity MCP setup documentation at https://docs.perplexity.ai/docs/getting-started/integrations/mcp-server. The remote endpoint is https://api.perplexity.ai/mcp. Prefer its supported OAuth sign-in flow when the host permits it. Explain that API usage bills the selected Perplexity API organization; verify billing availability rather than assuming a consumer subscription covers it.
3. If the host requires an API key instead, guide the user to create a key in their own Perplexity API organization and enter it in the host's credential settings. Never ask them to paste a key into chat, a document, a plugin manifest, or a transcript. If the host cannot store it securely, report that setup limitation.
4. For the existing local Claude runtime, follow the README's local installation and key setup procedure; do not impose that shell setup on a connected ChatGPT client.
5. Perform a harmless public search and open one original result using the host's source reader. Confirm search and reading independently. Report authentication, billing, or reading failures accurately.
6. If a durable record system is intended, save a clearly labeled fictional setup note and read it back with authorization. Do not claim the patient's research is retained merely because search succeeded. List any unfinished setup step.
