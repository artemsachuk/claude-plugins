# park

Park the ideas and bugs that pop up mid-feature, then pick them back up later —
without derailing the branch you're on.

`park` is a small companion to [superpowers](https://github.com/obra/superpowers)
for Claude Code.

## Why

You're deep in a feature branch and spot an unrelated bug, or a tempting new
idea. You don't want to bloat this branch with out-of-scope changes, but you
don't want to lose the thought either. **Park it.** `park` writes a dated note
— plus any analysis you've already done — to `docs/superpowers/parked_items/`,
so you can come back to it as separate work whenever you're ready.

## Requirements

- Claude Code
- The [superpowers](https://github.com/obra/superpowers) plugin — `park` stores
  items next to superpowers' own files and hands parked work back to its
  brainstorming / planning skills
- `git` and `bash` (already present on macOS and Linux)

## Install (macOS / Linux)

Inside Claude Code, add the marketplace and install:

```
/plugin marketplace add artemsachuk/claude-plugins
/plugin install park@as-claude-plugins
/reload-plugins
```

That's it — the `park` skill and the nudge hook are now active.

To hack on it locally, point `marketplace add` at a checkout of this repo
instead: `/plugin marketplace add /absolute/path/to/claude-plugins`.

## How to use it

**Park something:**

> park this bug: token refresh races on concurrent requests

→ writes `docs/superpowers/parked_items/2026-06-29-bug-token-refresh-races.md`
with a short note (and any spec/analysis already in the conversation).

**See what's parked:**

> what have I parked?

**Pick one back up:**

> let's pick up the token-refresh bug

→ `park` reads the note and hands it to superpowers to brainstorm deeper or go
straight to a plan. When the work is done, it offers to delete the note.

### The nudge

When you're mid-feature on a non-`main` branch (with real work already in
progress) and a spec or plan gets written, `park` quietly reminds you to
consider parking it if it's unrelated scope. It only ever *suggests* — it never
moves or deletes anything, and it stays silent on a fresh, empty branch.
