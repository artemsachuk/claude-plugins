#!/usr/bin/env bash
# Integration tests for hooks/park-nudge.sh (wrapper level).
# Creates throwaway git repos, drives the hook end-to-end, asserts stdout.
set -u

HOOK="$(cd "$(dirname "$0")/.." && pwd)/hooks/park-nudge.sh"
pass=0; fail=0
tmpdir_list=()

cleanup() {
  for d in "${tmpdir_list[@]+"${tmpdir_list[@]}"}"; do
    rm -rf "$d"
  done
}
trap cleanup EXIT

make_repo() {
  # Usage: make_repo <dir>
  # Initialises a git repo with an initial commit on main and returns.
  local dir="$1"
  git -C "$dir" init -q -b main 2>/dev/null \
    || git -C "$dir" init -q 2>/dev/null   # older git: no -b flag
  # Rename default branch to main if needed.
  git -C "$dir" symbolic-ref HEAD refs/heads/main 2>/dev/null || true
  git -C "$dir" config user.email "test@test.com"
  git -C "$dir" config user.name "Test"
  # Initial commit so main exists as a ref.
  touch "$dir/.gitkeep"
  git -C "$dir" add .gitkeep
  git -C "$dir" commit -q -m "init"
}

hook_output() {
  # Usage: hook_output <abs_file_path>
  # Pipes the JSON payload that Claude Code would send to the hook's stdin.
  local fpath="$1"
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fpath" \
    | bash "$HOOK"
}

assert_empty() {
  local desc="$1" got="$2"
  if [ -z "$got" ]; then
    pass=$((pass+1))
    echo "PASS: $desc"
  else
    fail=$((fail+1))
    echo "FAIL: $desc — expected empty output, got: $got"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" got="$3"
  if printf '%s' "$got" | grep -qF "$needle"; then
    pass=$((pass+1))
    echo "PASS: $desc"
  else
    fail=$((fail+1))
    echo "FAIL: $desc — expected output containing '$needle', got: $got"
  fi
}

# ---------------------------------------------------------------------------
# Case 1: Fresh branch off main, 0 commits ahead, ONLY the just-written spec
#         present — wrapper must print NOTHING (the bug being fixed).
# ---------------------------------------------------------------------------
d1="$(mktemp -d)"
tmpdir_list+=("$d1")
make_repo "$d1"
git -C "$d1" checkout -q -b feature/fresh
spec1="$d1/docs/superpowers/specs/2026-06-29-test-case1.md"
mkdir -p "$(dirname "$spec1")"
printf 'spec content' > "$spec1"
# Intentionally NOT committing or staging — it is a fresh untracked file
# (the hook has just "written" it; it is the only dirty item).
out1="$(hook_output "$spec1")"
assert_empty "Case 1: fresh branch, only triggering spec present → no nudge" "$out1"

# ---------------------------------------------------------------------------
# Case 2: Feature branch with at least 1 commit ahead of main.
# ---------------------------------------------------------------------------
d2="$(mktemp -d)"
tmpdir_list+=("$d2")
make_repo "$d2"
git -C "$d2" checkout -q -b feature/work
# Make a real commit ahead of main.
printf 'real work\n' > "$d2/src.js"
git -C "$d2" add src.js
git -C "$d2" commit -q -m "some real work"
# Write spec (the triggering file, not committed).
spec2="$d2/docs/superpowers/specs/2026-06-29-test-case2.md"
mkdir -p "$(dirname "$spec2")"
printf 'spec content' > "$spec2"
out2="$(hook_output "$spec2")"
assert_contains "Case 2: feature branch 1 commit ahead → nudge" "additionalContext" "$out2"

# ---------------------------------------------------------------------------
# Case 3: Fresh branch off main, 0 commits ahead, but a TRACKED file has been
#         modified (genuine work in progress) → wrapper prints JSON.
# ---------------------------------------------------------------------------
d3="$(mktemp -d)"
tmpdir_list+=("$d3")
make_repo "$d3"
git -C "$d3" checkout -q -b feature/wip
# Modify an already-tracked file (.gitkeep is committed by make_repo).
printf 'changed\n' > "$d3/.gitkeep"
# Write spec (the triggering file).
spec3="$d3/docs/superpowers/specs/2026-06-29-test-case3.md"
mkdir -p "$(dirname "$spec3")"
printf 'spec content' > "$spec3"
out3="$(hook_output "$spec3")"
assert_contains "Case 3: fresh branch but tracked file modified → nudge" "additionalContext" "$out3"

# ---------------------------------------------------------------------------
# Case 5: Fresh branch off main, 0 commits ahead, only an untracked noise file
#         (.DS_Store) present besides the spec → wrapper prints NOTHING.
#         This is the false-positive being fixed.
# ---------------------------------------------------------------------------
d5="$(mktemp -d)"
tmpdir_list+=("$d5")
make_repo "$d5"
git -C "$d5" checkout -q -b feature/noise
# An unrelated UNTRACKED noise file (never staged).
printf '\0\0' > "$d5/.DS_Store"
# Write spec (the triggering file, also untracked).
spec5="$d5/docs/superpowers/specs/2026-06-29-test-case5.md"
mkdir -p "$(dirname "$spec5")"
printf 'spec content' > "$spec5"
out5="$(hook_output "$spec5")"
assert_empty "Case 5: fresh branch, only untracked noise file → no nudge" "$out5"

# ---------------------------------------------------------------------------
# Case 4: On main → wrapper prints NOTHING.
# ---------------------------------------------------------------------------
d4="$(mktemp -d)"
tmpdir_list+=("$d4")
make_repo "$d4"
# Stay on main (no checkout).
spec4="$d4/docs/superpowers/specs/2026-06-29-test-case4.md"
mkdir -p "$(dirname "$spec4")"
printf 'spec content' > "$spec4"
out4="$(hook_output "$spec4")"
assert_empty "Case 4: on main → no nudge" "$out4"

# ---------------------------------------------------------------------------
# Case 6: Footprint exists (1 commit ahead in src/core); a file is created in
#         a NEW area (src/extra) → nudge mentioning scope-guard.
# ---------------------------------------------------------------------------
d6="$(mktemp -d)"
tmpdir_list+=("$d6")
make_repo "$d6"
git -C "$d6" checkout -q -b feature/area
mkdir -p "$d6/src/core"
printf 'core\n' > "$d6/src/core/a.js"
git -C "$d6" add src/core/a.js
git -C "$d6" commit -q -m "core work"
mkdir -p "$d6/src/extra"
printf 'extra\n' > "$d6/src/extra/b.js"
out6="$(hook_output "$d6/src/extra/b.js")"
assert_contains "Case 6: new-area edit with footprint → nudge" "additionalContext" "$out6"
assert_contains "Case 6: nudge points at scope-guard" "scope-guard" "$out6"

# ---------------------------------------------------------------------------
# Case 7: Footprint in src/auth; another file edited in the SAME area → silent.
# ---------------------------------------------------------------------------
d7="$(mktemp -d)"
tmpdir_list+=("$d7")
make_repo "$d7"
git -C "$d7" checkout -q -b feature/samearea
mkdir -p "$d7/src/auth"
printf 'a\n' > "$d7/src/auth/a.js"
git -C "$d7" add src/auth/a.js
git -C "$d7" commit -q -m "auth work"
printf 'b\n' > "$d7/src/auth/b.js"
out7="$(hook_output "$d7/src/auth/b.js")"
assert_empty "Case 7: same-area edit → no nudge" "$out7"

# ---------------------------------------------------------------------------
# Case 8: New-area edit, but the area is listed in the branch scope-cache's
#         accepted_areas → silent (suppression).
# ---------------------------------------------------------------------------
d8="$(mktemp -d)"
tmpdir_list+=("$d8")
make_repo "$d8"
git -C "$d8" checkout -q -b feature/accepted
mkdir -p "$d8/src/core"
printf 'core\n' > "$d8/src/core/a.js"
git -C "$d8" add src/core/a.js
git -C "$d8" commit -q -m "core work"
mkdir -p "$d8/.git/park-scope"
cat > "$d8/.git/park-scope/feature-accepted.md" <<'CACHE'
---
branch: feature/accepted
intent: test intent
established: 2026-06-30
accepted_areas:
  - src/extra
---
CACHE
mkdir -p "$d8/src/extra"
printf 'extra\n' > "$d8/src/extra/b.js"
out8="$(hook_output "$d8/src/extra/b.js")"
assert_empty "Case 8: new-area edit but area accepted → no nudge" "$out8"

# ---------------------------------------------------------------------------
# Case 9: A file MODIFIED (not newly created) in an area the branch hasn't
#         touched. Exercises the triggering-file exclusion on the tracked path.
# ---------------------------------------------------------------------------
d9="$(mktemp -d)"
tmpdir_list+=("$d9")
make_repo "$d9"
# src/legacy exists on main (committed before branching).
mkdir -p "$d9/src/legacy"
printf 'old\n' > "$d9/src/legacy/old.js"
git -C "$d9" add src/legacy/old.js
git -C "$d9" commit -q -m "legacy on main"
git -C "$d9" checkout -q -b feature/mod
# Footprint in a different area.
mkdir -p "$d9/src/core"
printf 'core\n' > "$d9/src/core/a.js"
git -C "$d9" add src/core/a.js
git -C "$d9" commit -q -m "core work"
# Now modify the tracked legacy file — a NEW area for this branch.
printf 'changed\n' >> "$d9/src/legacy/old.js"
out9="$(hook_output "$d9/src/legacy/old.js")"
assert_contains "Case 9: modify tracked file in new area → nudge" "additionalContext" "$out9"

# ---------------------------------------------------------------------------
# Case 10: accepted_areas holds a PREFIX of the edited area ("src/ex" vs the
#          edited "src/extra"). The anchored match must NOT suppress → nudge.
# ---------------------------------------------------------------------------
d10="$(mktemp -d)"
tmpdir_list+=("$d10")
make_repo "$d10"
git -C "$d10" checkout -q -b feature/prefix
mkdir -p "$d10/src/core"
printf 'core\n' > "$d10/src/core/a.js"
git -C "$d10" add src/core/a.js
git -C "$d10" commit -q -m "core work"
mkdir -p "$d10/.git/park-scope"
cat > "$d10/.git/park-scope/feature-prefix.md" <<'CACHE'
---
branch: feature/prefix
intent: test intent
established: 2026-06-30
accepted_areas:
  - src/ex
---
CACHE
mkdir -p "$d10/src/extra"
printf 'extra\n' > "$d10/src/extra/b.js"
out10="$(hook_output "$d10/src/extra/b.js")"
assert_contains "Case 10: accepted prefix 'src/ex' must NOT suppress 'src/extra'" "additionalContext" "$out10"

# ---------------------------------------------------------------------------
# Case 11: Writing a parked item (docs/superpowers/parked_items/...) is a new
#          area for the branch, but park's own bookkeeping must NOT self-nudge.
# ---------------------------------------------------------------------------
d11="$(mktemp -d)"
tmpdir_list+=("$d11")
make_repo "$d11"
git -C "$d11" checkout -q -b feature/parking
mkdir -p "$d11/src/core"
printf 'core\n' > "$d11/src/core/a.js"
git -C "$d11" add src/core/a.js
git -C "$d11" commit -q -m "core work"
parked="$d11/docs/superpowers/parked_items/2026-06-30-feature-x.md"
mkdir -p "$(dirname "$parked")"
printf 'parked note\n' > "$parked"
out11="$(hook_output "$parked")"
assert_empty "Case 11: writing a parked item → no self-nudge" "$out11"

# ---------------------------------------------------------------------------
echo ""
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
