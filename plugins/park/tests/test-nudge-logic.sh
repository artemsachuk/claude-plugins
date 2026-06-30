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

# assert_area <expected> <input-path>
assert_area() {
  local expected="$1" input="$2" got
  got="$(path_area "$input")"
  if [ "$got" = "$expected" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: path_area '$input' (expected '$expected', got '$got')"
  fi
}

# path_area
assert_area "src/auth"  "src/auth/token.js"
assert_area "src/auth"  "src/auth/utils/helper.js"
assert_area "src"       "src/app.js"
assert_area "."         "app.js"
assert_area "a/b"       "a/b/c/d/e.js"
assert_area "pkg"       "pkg/main.go"
assert_area "."         "Makefile"

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

# Signal A: new-area edits (args 5,6 = is_new_area, is_accepted)
assert_nudge yes "new-area edit, dirty"             "$OTHER" feat 0 1 1 0
assert_nudge no  "same-area edit (not new)"         "$OTHER" feat 0 1 0 0
assert_nudge no  "new-area edit but accepted"       "$OTHER" feat 0 1 1 1
assert_nudge no  "new-area edit but no WIP"         "$OTHER" feat 0 0 1 0
assert_nudge no  "new-area edit on main"            "$OTHER" main 0 1 1 0

# Signal B precedence: spec/plan write nudges regardless of signal-A flags
assert_nudge yes "spec write, area not new"         "$SPEC" feat 2 0 0 0
assert_nudge yes "spec write, area 'accepted'"      "$SPEC" feat 2 0 1 1

# Signal A must ignore park/superpowers bookkeeping (gitignored tree): writing a
# parked item lands in a "new area" (docs/superpowers) but must NOT self-nudge.
PARKED="docs/superpowers/parked_items/2026-06-30-feature-x.md"
assert_nudge no  "parked-item write not flagged as drift" "$PARKED" feat 2 1 1 0

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
