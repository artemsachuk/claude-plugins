#!/usr/bin/env bash
# Tests for should_nudge — pure decision logic, no git required.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../hooks/nudge-logic.sh"

pass=0; fail=0

# assert_nudge <expected: yes|no> <desc> <path> <branch> <ahead> <dirty>
assert_nudge() {
  local expected="$1" desc="$2"; shift 2
  if should_nudge "$@"; then got=yes; else got=no; fi
  if [ "$got" = "$expected" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: $desc (expected $expected, got $got)"
  fi
}

SPEC="docs/superpowers/specs/2026-06-29-x-design.md"
PLAN="docs/superpowers/plans/2026-06-29-x.md"
OTHER="src/app.js"

# Path gating
assert_nudge no  "write outside specs/plans"        "$OTHER" feature 3 1
assert_nudge yes "write to specs dir"               "$SPEC"  feature 3 0
assert_nudge yes "write to plans dir"               "$PLAN"  feature 0 1

# Branch gating
assert_nudge no  "on main"                          "$SPEC"  main    3 1
assert_nudge no  "on master"                        "$SPEC"  master  3 1
assert_nudge no  "empty branch name"                "$SPEC"  ""      3 1

# Work-in-progress guard
assert_nudge no  "off-main, empty branch, clean"    "$SPEC"  feat    0 0
assert_nudge yes "off-main, commits ahead"          "$SPEC"  feat    2 0
assert_nudge yes "off-main, dirty tree"             "$SPEC"  feat    0 1
assert_nudge yes "off-main, commits and dirty"      "$SPEC"  feat    2 1

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
