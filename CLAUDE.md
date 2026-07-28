# research-engine

> **This file was generated from what is on disk and is a starting point, not a finished
> root.** Everything below is derived — the toolchain, the git setup, the summary line from
> `status.yml`. What a CLAUDE.md is actually for is the part no generator can
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

## Where each question is answered here

| The question a session asks | Answered here by |
|---|---|
| What is this project, and what constrains it? | this file |
| Where does the work stand? | `status.yml` |
| What is blocking? | `status.yml` `open[]` — this project has no `register.json` |

Only bound slots are listed. The full question list is in
`~/.claude/rules/state-capture-protocol.md`, which loads every session; a question not in the
table above is unbound here, and binding one adds its row here.

## Where current state lives

`status.yml` in this folder holds the changing half: where the work stands, what is open,
what was last worked on. This file carries only the durable half. A sentence that would be
false next month belongs in `status.yml` instead of here.
