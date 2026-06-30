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

### The scope-guard

The nudge above is the simple case. `park` also watches for **derailing** — when
the work itself drifts from your branch's goal — and offers to park it before
the tangent grows. Small branches are easy to review and merge; sprawling ones
aren't, so the guard exists to keep you on track.

**What trips it.** A quiet hook watches for two structural signals on a
non-`main` branch that already has real work in progress:

- you edit a **new area** of the codebase the branch hasn't touched yet (the
  classic "while I'm here…" tangent), or
- a **spec or plan** gets written mid-branch.

The hook only *notices* — it never decides. When a signal trips, Claude figures
out your branch's goal (from a spec/plan, the conversation, or by asking you
once) and judges whether the change is genuinely off-track. If it looks
in-scope, you hear nothing.

**What happens when it's real drift.** Claude pauses, names the drift, and gives
you the call — three options, nothing automatic:

- **Park it.** Claude saves the drifting work as a parked item — the actual
  code changes (as a patch) *plus* a written description — then cleanly reverts
  those file changes so your branch stays focused. Resuming the parked item can
  re-apply the patch.
- **This is in-scope.** Claude widens the branch's remembered goal and stops
  flagging that area.
- **Expand scope deliberately.** Same as above, your choice on the record.

**Side effects are handled honestly.** Reverting files can't undo a database
migration you already ran, a dependency you installed, or other real-world
changes. When the drift involves those, `park` won't pretend it cleaned up — it
still saves the code, lists exactly what git can't undo, and asks how you want
to handle the rollback. It never runs a destructive rollback (a `down`
migration, a `DROP`, deleting a resource) on its own.

Everything the guard does — every revert, every choice — waits for your explicit
go-ahead. It guards your scope; it never takes the wheel.
