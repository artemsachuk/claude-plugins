#!/usr/bin/env bash
# Pure decision logic for the park nudge hook. Sourceable; defines functions
# only, runs nothing on its own.

# should_nudge <changed_path> <branch> <ahead_count> <dirty>
# Returns 0 (nudge) when ALL hold:
#   1. changed_path is under docs/superpowers/specs/ or docs/superpowers/plans/
#   2. branch is non-empty and not main/master
#   3. ahead_count > 0 OR dirty == 1  (branch has real work in progress)
# Returns 1 otherwise.
should_nudge() {
  local path="$1" branch="$2" ahead="$3" dirty="$4"

  case "$path" in
    *docs/superpowers/specs/*|*docs/superpowers/plans/*) ;;
    *) return 1 ;;
  esac

  case "$branch" in
    ""|main|master) return 1 ;;
  esac

  if [ "${ahead:-0}" -gt 0 ] 2>/dev/null; then
    return 0
  fi
  if [ "${dirty:-0}" = "1" ]; then
    return 0
  fi
  return 1
}
