#!/usr/bin/env bash
# Tests for scripts/release.sh against a throwaway fixture repo.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RELEASE="$REPO_ROOT/scripts/release.sh"
pass=0; fail=0
workdirs=()

cleanup() {
  for d in "${workdirs[@]+"${workdirs[@]}"}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
}
trap cleanup EXIT

check() {
  local desc="$1" cond="$2"
  if [ "$cond" = "1" ]; then
    pass=$((pass+1)); echo "PASS: $desc"
  else
    fail=$((fail+1)); echo "FAIL: $desc"
  fi
}

# Build a fixture marketplace repo with one plugin at version 0.1.0 whose
# CHANGELOG has unreleased content. Echoes the repo path.
make_fixture() {
  local root
  root="$(mktemp -d)"
  workdirs+=("$root")
  mkdir -p "$root/scripts" "$root/plugins/demo/.claude-plugin"
  cp "$RELEASE" "$root/scripts/release.sh"
  printf '{\n  "name": "demo",\n  "version": "0.1.0"\n}\n' \
    > "$root/plugins/demo/.claude-plugin/plugin.json"
  cat > "$root/plugins/demo/CHANGELOG.md" <<'EOF'
# Changelog

## [Unreleased]

### Added
- A shiny new thing.

## [0.1.0] - 2026-06-01

### Added
- First cut.
EOF
  git -C "$root" init -q
  git -C "$root" config user.email test@example.com
  git -C "$root" config user.name Test
  git -C "$root" add -A
  git -C "$root" commit -q -m "init"
  git -C "$root" branch -M main
  printf '%s' "$root"
}

# --- Real release ---------------------------------------------------------
root="$(make_fixture)"
( cd "$root" && bash scripts/release.sh demo 0.2.0 ) >/dev/null 2>&1
rc=$?
check "release exits 0" "$([ $rc -eq 0 ] && echo 1 || echo 0)"

ver="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["version"])' "$root/plugins/demo/.claude-plugin/plugin.json")"
check "manifest bumped to 0.2.0" "$([ "$ver" = "0.2.0" ] && echo 1 || echo 0)"

cl="$(cat "$root/plugins/demo/CHANGELOG.md")"
check "changelog has [0.2.0] section" "$(printf '%s' "$cl" | grep -q '## \[0.2.0\]' && echo 1 || echo 0)"
check "released content moved under 0.2.0" \
  "$(printf '%s' "$cl" | awk '/## \[0.2.0\]/{f=1} f&&/A shiny new thing/{print "1"; exit}' | grep -q 1 && echo 1 || echo 0)"
check "fresh empty [Unreleased] remains" \
  "$(printf '%s' "$cl" | awk '/## \[Unreleased\]/{getline; if ($0 ~ /^$/) print "1"}' | grep -q 1 && echo 1 || echo 0)"
check "tag demo-v0.2.0 created" \
  "$(git -C "$root" rev-parse -q --verify refs/tags/demo-v0.2.0 >/dev/null && echo 1 || echo 0)"
check "release commit made" \
  "$(git -C "$root" log -1 --pretty=%s | grep -q 'Release demo v0.2.0' && echo 1 || echo 0)"

# --- Dry run writes nothing ----------------------------------------------
root2="$(make_fixture)"
before="$(cat "$root2/plugins/demo/.claude-plugin/plugin.json")"
( cd "$root2" && bash scripts/release.sh --dry-run demo 0.2.0 ) >/dev/null 2>&1
after="$(cat "$root2/plugins/demo/.claude-plugin/plugin.json")"
check "dry-run leaves manifest unchanged" "$([ "$before" = "$after" ] && echo 1 || echo 0)"
check "dry-run creates no tag" \
  "$(git -C "$root2" rev-parse -q --verify refs/tags/demo-v0.2.0 >/dev/null && echo 0 || echo 1)"

# --- Rejections -----------------------------------------------------------
root3="$(make_fixture)"
if ( cd "$root3" && bash scripts/release.sh demo 0.0.9 ) >/dev/null 2>&1; then rc3=0; else rc3=1; fi
check "rejects non-increasing version" "$([ "$rc3" = "1" ] && echo 1 || echo 0)"

root4="$(make_fixture)"
if ( cd "$root4" && bash scripts/release.sh demo 1.2 ) >/dev/null 2>&1; then rc4=0; else rc4=1; fi
check "rejects non-semver version" "$([ "$rc4" = "1" ] && echo 1 || echo 0)"

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
