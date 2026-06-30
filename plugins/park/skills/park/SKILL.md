---
name: park
description: Use when the user wants to set aside an idea, bug, or spec for later — phrasings like "park this", "save this for later", "stash this idea/bug/spec", "set this aside" — or wants to list/resume previously parked items. Companion to superpowers.
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
3. Hand its content to superpowers:
   - To explore/refine further → invoke `superpowers:brainstorming` with the
     parked context as the starting idea.
   - To go straight to implementation → invoke `superpowers:writing-plans`
     using the captured material as the spec.
4. Let the user decide which path; default to brainstorming if unsure.

## Mode D: Completing a parked item

When work resumed from a parked item is finished:

- **Offer to delete** the parked-item file. Do not delete automatically and do
  not move it to a `done/` folder. Wait for the user's confirmation, then
  delete it.
