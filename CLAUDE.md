# research-engine

> **This file was generated from what is on disk and is a starting point, not a finished
> root.** Everything below is derived — the tree, the toolchain, the git setup, the summary
> line from `status.yml`. What a CLAUDE.md is actually for is the part no generator can
> produce: the gotchas, the constraint learned the hard way, the thing that looks wrong and
> is deliberate. **Replace this note with those the first time you work here and learn one.**
> Until then, treat this file as an index and `status.yml` as the truth about current state.

> **The names in this project have not been checked against**
> **`~/assistant/docs/naming-files-and-folders.md`.** Next time you work here, check whether
> its folders and files are named for the words that will be in a session's context at the
> moment of needing them — not for what the thing contains, and not for the correct technical
> term, which measured worse. Rename what does not fit, then delete this paragraph.

## Git

Its own git repository. Default branch `main`, origin `https://github.com/Family-IT-Guy/research-engine.git`. Branch freely here; the assistant repo's master-only rule does not apply.

## Layout

```
agents/
quick/
  cascades/
  raw/
  sources/
references/
research/
  cascades/
  raw/
  sources/
scripts/
skills/
  execute/
  orchestrate/
  query/
  retrieve/
```

## Where each question is answered here

The per-project slots from `~/.claude/rules/state-capture-protocol.md`. Bind an unbound one
the first time you have something to put in it: create the file, name it per
`~/assistant/docs/naming-files-and-folders.md`, and fill in its row in the same turn.

| The question a session asks | Answered here by |
|---|---|
| What is this project, and what constrains it? | this file |
| Where does the work stand? | `status.yml` |
| What is blocking? | `status.yml` `open[]` — this project has no `register.json` |
| What do we already know about X? | **unbound** |
| What was tried, and what happened? | **unbound** |
| What was raised and left open? | **unbound** |
| What is parked, and what unparks it? | **unbound** |
| What is the plan, and what phase is it in? | **unbound** |
| Why is it built this way? | **unbound** — the decision itself goes to `decisions-append.py` |

## Where current state lives

`status.yml` in this folder holds the changing half: where the work stands, what is open,
what was last worked on. This file carries only the durable half. A sentence that would be
false next month belongs in `status.yml` instead of here.
