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

should_nudge "$file_path" "$branch" "$ahead" "$dirty" || exit 0

# Emit the reminder as PostToolUse additionalContext.
msg="You're mid-feature on branch '"
msg="${msg}${branch}"
msg="${msg}'. If this spec/plan is unrelated scope, consider parking it with the park skill instead of building it on this branch."

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
