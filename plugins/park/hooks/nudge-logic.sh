#!/usr/bin/env bash
# Pure decision logic for the park nudge hook. Sourceable; defines functions
# only, runs nothing on its own.

# path_area <path>
# Echoes the "area" of a path: its directory capped at the first 2 path
# components. Root-level files yield ".".
#   src/auth/token.js        -> src/auth
#   src/auth/utils/helper.js -> src/auth
#   src/app.js               -> src
#   app.js                   -> .
path_area() {
  local p="$1" dir a b rest
  dir="$(dirname "$p")"
  if [ "$dir" = "." ] || [ -z "$dir" ]; then
    printf '.'
    return 0
  fi
  IFS=/ read -r a b rest <<<"$dir"
  if [ -n "$b" ]; then
    printf '%s/%s' "$a" "$b"
  else
    printf '%s' "$a"
  fi
}

# should_nudge <path> <branch> <ahead> <dirty> [is_new_area] [is_accepted]
# Returns 0 (nudge) when the branch is a real in-progress feature branch AND
# either signal fires:
#   B: path is under docs/superpowers/specs/ or docs/superpowers/plans/
#   A: is_new_area == 1 AND is_accepted != 1  (edit jumped to an untouched area)
# is_new_area / is_accepted default to 0 when omitted (signal-B-only check).
should_nudge() {
  local path="$1" branch="$2" ahead="$3" dirty="$4"
  local is_new_area="${5:-0}" is_accepted="${6:-0}"

  # Branch gate.
  case "$branch" in
    ""|main|master) return 1 ;;
  esac

  # Work-in-progress gate: branch must have a real footprint.
  local wip=0
  if [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then wip=1; fi
  if [ "${dirty:-0}" = "1" ]; then wip=1; fi
  [ "$wip" = "1" ] || return 1

  # Signal B: spec/plan write.
  case "$path" in
    *docs/superpowers/specs/*|*docs/superpowers/plans/*) return 0 ;;
  esac

  # Signal A: new-area edit, not already accepted as in-scope. Skip the
  # docs/superpowers/ tree — it is park/superpowers bookkeeping (gitignored,
  # never part of a branch's code footprint), so parking or planning there
  # must not self-nudge. (Spec/plan writes already returned via signal B.)
  case "$path" in
    *docs/superpowers/*) return 1 ;;
  esac
  if [ "$is_new_area" = "1" ] && [ "$is_accepted" != "1" ]; then
    return 0
  fi

  return 1
}
