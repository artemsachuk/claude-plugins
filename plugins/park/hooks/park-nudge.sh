#!/usr/bin/env bash
# PostToolUse hook: nudge to consider parking when a spec/plan is written
# mid-feature on a non-main branch. Silent no-op on any failure.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/nudge-logic.sh" 2>/dev/null || exit 0

# Read hook input JSON from stdin.
input="$(cat)"

# Extract tool_input.file_path with a tolerant regex (no jq dependency).
file_path="$(printf '%s' "$input" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
  | head -n1 \
  | sed 's/.*"file_path"[[:space:]]*:[[:space:]]*"//; s/"$//')"

# Nothing to do if we could not find a path.
[ -n "$file_path" ] || exit 0

# Locate the repo containing the changed file.
file_dir="$(dirname "$file_path")"
[ -d "$file_dir" ] || file_dir="."
branch="$(git -C "$file_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" || exit 0
[ -n "$branch" ] || exit 0

# Determine base branch: prefer main, then master.
base=""
if git -C "$file_dir" show-ref --verify --quiet refs/heads/main 2>/dev/null; then
  base="main"
elif git -C "$file_dir" show-ref --verify --quiet refs/heads/master 2>/dev/null; then
  base="master"
fi

# Commits ahead of base (0 if no base or on the base itself).
ahead=0
if [ -n "$base" ] && [ "$branch" != "$base" ]; then
  ahead="$(git -C "$file_dir" rev-list --count "${base}..HEAD" 2>/dev/null || echo 0)"
fi

# Dirty working tree, counting only tracked modifications and staged changes.
# `-uno` omits untracked files entirely, so unrelated noise (.DS_Store, editor
# swap files, build artifacts) — and the freshly-written triggering spec, which
# is itself untracked — never register as "real work in progress".
dirty=0
repo_root="$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$repo_root" ]; then
  out="$(git -C "$repo_root" status --porcelain -uno 2>/dev/null)"
  [ -n "$out" ] && dirty=1
fi

# --- Signal A: new-area detection -----------------------------------------
# Determine whether the edited file lands in an area the branch has not yet
# touched, and whether that area was already accepted as in-scope.
is_new_area=0
is_accepted=0
if [ -n "$repo_root" ]; then
  # Repo-relative path of the edited file. Derived via git's show-prefix so it
  # is correct even when repo_root and file_path differ only by a symlinked
  # prefix (e.g. macOS /var vs /private/var).
  prefix="$(git -C "$file_dir" rev-parse --show-prefix 2>/dev/null)"
  rel="${prefix}${file_path##*/}"
  edited_area="$(path_area "$rel")"

  # Areas the branch has already touched, EXCLUDING the triggering file
  # itself (it is the candidate new-area edit). Sources: commits ahead of
  # base, plus tracked working-tree changes vs HEAD.
  touched_areas="$(
    {
      if [ -n "$base" ] && [ "$branch" != "$base" ]; then
        git -C "$repo_root" diff --name-only "${base}..HEAD" 2>/dev/null
      fi
      git -C "$repo_root" diff --name-only HEAD 2>/dev/null
    } | grep -vxF "$rel" 2>/dev/null | while IFS= read -r f; do
          [ -n "$f" ] || continue
          printf '%s\n' "$(path_area "$f")"
        done | sort -u
  )"

  if [ -n "$edited_area" ] \
     && ! printf '%s\n' "$touched_areas" | grep -qxF "$edited_area"; then
    is_new_area=1
  fi

  # Accepted-area suppression: grep accepted_areas from the branch cache.
  git_dir="$(git -C "$repo_root" rev-parse --absolute-git-dir 2>/dev/null)"
  if [ -n "$git_dir" ]; then
    branch_slug="${branch//\//-}"
    cache="${git_dir}/park-scope/${branch_slug}.md"
    if [ -f "$cache" ]; then
      esc="$(printf '%s' "$edited_area" | sed 's/[][\\.^$*/]/\\&/g')"
      if grep -qE "^[[:space:]]*-[[:space:]]+${esc}[[:space:]]*$" "$cache" 2>/dev/null; then
        is_accepted=1
      fi
    fi
  fi
fi

should_nudge "$file_path" "$branch" "$ahead" "$dirty" "$is_new_area" "$is_accepted" || exit 0

# Emit the reminder as PostToolUse additionalContext.
msg="You may be drifting from the goal of branch '"
msg="${msg}${branch}"
msg="${msg}'. Use the park skill's scope-guard (Mode E) to check this change: if it's unrelated scope, park it (the skill captures the diff and reverts the files); if it's genuinely in-scope, say so to stop future nudges on that area."

# Minimal JSON string escaping for the message.
escape_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf '%s' "$s"
}
msg_escaped="$(escape_json "$msg")"

printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "PostToolUse",\n    "additionalContext": "%s"\n  }\n}\n' "$msg_escaped"
exit 0
