---
name: research-engine:retrieve
description: >-
  Knowledge retrieval from research files. Invoke when the user asks "what do we
  know about X?", "have we researched X?", "any notes on X?", or before
  dispatching new research to check existing coverage.
  Also used by :orchestrate for batch coverage checks.
---

# Research Engine: Retrieve

When connected to a record system, search its research records for the requested topic and retrieve the actual notes with dates, citations, and uncertainties. Follow pagination. If Health Charted is connected, select the person and read research-notes with get_records. Report unavailable coverage as unknown. Do not assume local research files exist in a connected client.

Only when a local research directory is available:

Read `../../references/retrieve.md` (relative to this skill's directory) and follow it step by step.
