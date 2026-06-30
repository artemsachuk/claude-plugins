---
name: park
description: Use when the user wants to set aside an idea, bug, or spec for later — phrasings like "park this", "save this for later", "stash this idea/bug/spec", "set this aside" — or wants to list/resume previously parked items, or to check whether the current change is drifting from the branch's goal (scope-guard). Companion to superpowers.
---

# Park

Capture an idea/bug/spec that surfaced mid-feature so it can be resumed later
as separate work, without bloating the current branch's scope.

Parked items live in `docs/superpowers/parked_items/` as plain markdown.

## Mode A: Parking something

When the user asks to park/save/stash/set-aside something:

1. **Determine the type.** `feature` or `bug`. Infer from the user's wording;
   if genuinely ambiguous, ask once.
2. **Write a one-line gist** capturing the essence. Derive a `gist-slug`:
   lowercase, words joined by `-`, alphanumeric only, max ~6 words.
3. **Read the origin branch** (best-effort):
   `git rev-parse --abbrev-ref HEAD 2>/dev/null`. If not a git repo, leave
   `origin_branch` empty.
4. **Ensure the directory exists:** create `docs/superpowers/parked_items/`
   if missing.
5. **Pick the filename:** `docs/superpowers/parked_items/<YYYY-MM-DD>-<type>-<gist-slug>.md`
   using today's date. If that file already exists, append `-2`, `-3`, … to
   the slug until unique.
6. **Write the file** in this exact format:

   ```markdown
   ---
   parked: <YYYY-MM-DD>
   type: <feature|bug>
   gist: <one-line gist>
   origin_branch: <branch or empty>
   ---

   ## Context
   <2-4 sentences: what the user was doing, why this came up, why it's out
   of scope for the current branch>

   ## Captured material
   <Include this section ONLY if a real spec, plan, or analysis already
   exists in the conversation. Paste it verbatim. If nothing real exists yet,
   OMIT this section entirely — do not write a placeholder.>
   ```

7. **Confirm** to the user: filename written and one-line gist.

**Do not** start implementing the parked idea. Parking means deferring.

## Mode B: Listing parked items

When the user asks what they've parked (or which bugs/features are parked):

1. Glob `docs/superpowers/parked_items/*.md`.
2. For each, read the frontmatter and present: date, type, gist, origin_branch.
3. Sort newest first. If the directory is empty or missing, say so.

## Mode C: Resuming a parked item

When the user picks one to work on ("let's pick up the token-refresh bug"):

1. Match their request to a file (by gist/type/date). If several match, list
   the candidates and ask which.
2. Read the file.
3. If the file's `## Captured material` contains a `diff`/patch block, offer to
   re-apply it on the current branch with `git apply` instead of starting from
   scratch. If `git apply` fails (context drift), fall back to applying the
   changes by hand from the patch.
4. If the file has a `## Side effects — manual rollback required` section,
   surface those steps so the user re-establishes the required state (re-run a
   migration, reinstall a dependency, etc.) before continuing.
5. Hand its content to superpowers:
   - To explore/refine further → invoke `superpowers:brainstorming` with the
     parked context as the starting idea.
   - To go straight to implementation → invoke `superpowers:writing-plans`
     using the captured material as the spec.
6. Let the user decide which path; default to brainstorming if unsure.

## Mode D: Completing a parked item

When work resumed from a parked item is finished:

- **Offer to delete** the parked-item file. Do not delete automatically and do
  not move it to a `done/` folder. Wait for the user's confirmation, then
  delete it.

## Mode E: Scope-guard (am I derailing?)

Enter this mode when the nudge hook injects a scope-drift message, or when the
user asks directly ("am I drifting?", "is this in scope?"). The goal: catch
scope creep before a tangent grows, and offer to park it cleanly.

### Step 1 — Establish or load the branch intent

The intent anchors what "in scope" means for this branch. Resolve it in order:

1. Read the branch's scope-cache file (see *The scope-cache* below). If it
   exists, use its `intent` and `accepted_areas`.
2. Otherwise derive the intent: the spec/plan doc for this branch (under
   `docs/superpowers/specs|plans/`) → else infer it from the conversation →
   else, only if genuinely unclear, **ask the user once** for a one-line goal.
3. Write the resolved intent to the cache so this ask happens at most once per
   branch.

### Step 2 — Judge the drift

Compare the triggering change against the intent. If it is plausibly in-scope,
**say nothing and stop** — the hook only flags structural signals, so cheap
false positives are expected. Continue only if it is genuine drift.

### Step 3 — Classify reversibility BEFORE offering to park

Inspect the drifting change for **side effects git cannot undo**, using two
sources:

- **The diff:** migration files (`migrations/`, `*.sql` up/down), schema/DDL
  changes, dependency-manifest edits (`package.json`, `requirements.txt`, …),
  seed/fixture scripts, infra-as-code.
- **The conversation:** did you already *execute* a migration, install, or other
  state-changing command in this session as part of this work?

This yields one of the two paths below.

### Step 4a — Clean (file-only) drift → capture-then-revert

1. Write the parked item **first** (use Mode A's format). In
   `## Captured material`, include the prose context (what / why / why
   out-of-scope) **and the verbatim `git diff` patch** of the drifting change in
   a fenced ```diff block.
2. Show the user exactly which paths/hunks will be reverted. On confirmation,
   `git restore` modified tracked files and `rm` newly-created files.
3. The branch returns to its focused state; the patch in the parked item is the
   recovery copy.

**Tangled case:** if drift is mixed into a file that is already in-scope, do not
blunt-revert the whole file — capture only the out-of-scope hunks into the patch
and restore only those. If you cannot cleanly separate them, say so and leave
the file untouched rather than risk losing in-scope work.

### Step 4b — Side-effecting drift → park, but DO NOT pretend to revert

`git restore` only undoes tracked file *content* — never an applied migration,
executed SQL, installed dependency, created resource, or written data. So when
side effects are present:

1. Still capture the code patch into the parked item.
2. Add a `## Side effects — manual rollback required` section listing exactly
   what git cannot undo (e.g. *"migration `0007_add_audit_log` was applied — run
   its `down` to roll back the DB"*, *"`pyjwt` was added and installed"*).
3. Present honest options — never a fake-clean revert:
   - **Park + user handles rollback** — you may *generate* the down-migration or
     uninstall steps, but do not run destructive operations yourself.
   - **Park code only, leave side effects in place** — flag the inconsistency in
     the parked item.
   - **Don't park — finish or deliberately expand scope** — because the work is
     already entangled with real state.
4. State which you recommend and why; the user decides. **Never** auto-run a
   destructive rollback (`migrate down`, `DROP`, resource deletion) without
   explicit confirmation.

### Step 5 — If the user says "this is in-scope"

Append the edited area to the cache's `accepted_areas`, and widen the cached
`intent` if needed. The hook then stops re-nudging on that area.

### The scope-cache

Per-branch state lives at `<git-dir>/park-scope/<branch-slug>.md`, where
`<git-dir>` is `git rev-parse --absolute-git-dir` and `<branch-slug>` is the
branch name with `/` replaced by `-`. Living under the git dir keeps it out of
the repo diff. Format:

```markdown
---
branch: fix/token-refresh
intent: <one-line goal / scope boundary>
established: <YYYY-MM-DD>
accepted_areas:
  - src/analytics
---
<optional free-form notes about scope>
```

When you run this mode, **opportunistically prune** cache files whose branch no
longer exists (`git branch --list <branch>` returns nothing) — they are
harmless but tidy to remove.

**Do not** start implementing the drifting idea. Scope-guard defers it.
