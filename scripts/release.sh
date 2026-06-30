#!/usr/bin/env bash
# Cut a release for one plugin in this marketplace.
#
# Usage: scripts/release.sh [--dry-run] <plugin> <version>
#
# Bumps the plugin's manifest version, rolls its CHANGELOG [Unreleased] section
# into a dated version section, commits, and creates a `<plugin>-v<version>`
# annotated tag. It never pushes and never creates a GitHub Release — it prints
# the commands for you to run.
set -euo pipefail

dry_run=0
if [ "${1:-}" = "--dry-run" ]; then
  dry_run=1
  shift
fi

plugin="${1:-}"
version="${2:-}"

if [ -z "$plugin" ] || [ -z "$version" ]; then
  echo "usage: scripts/release.sh [--dry-run] <plugin> <version>" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

plugin_dir="plugins/$plugin"
manifest="$plugin_dir/.claude-plugin/plugin.json"
changelog="$plugin_dir/CHANGELOG.md"

[ -d "$plugin_dir" ] || { echo "error: no such plugin: $plugin ($plugin_dir missing)" >&2; exit 1; }
[ -f "$manifest" ]   || { echo "error: missing manifest: $manifest" >&2; exit 1; }
[ -f "$changelog" ]  || { echo "error: missing changelog: $changelog" >&2; exit 1; }

if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "error: version must be MAJOR.MINOR.PATCH, got: $version" >&2
  exit 1
fi

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
if [ "$branch" != "main" ]; then
  echo "error: releases must be cut from main (currently on '$branch')" >&2
  exit 1
fi
if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree not clean; commit or stash changes first" >&2
  exit 1
fi

current="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$manifest")"
if [ "$version" = "$current" ] || \
   [ "$(printf '%s\n%s\n' "$current" "$version" | sort -V | tail -n1)" != "$version" ]; then
  echo "error: version $version is not greater than current $current" >&2
  exit 1
fi

tag="${plugin}-v${version}"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "error: tag already exists: $tag" >&2
  exit 1
fi

# Validate + (unless dry-run) rewrite the manifest version and CHANGELOG section.
# Prints a human summary to stdout; writes files only when DRY_RUN=0.
MANIFEST="$manifest" CHANGELOG="$changelog" VERSION="$version" DRY_RUN="$dry_run" python3 <<'PY'
import datetime
import json
import os
import re
import sys

manifest = os.environ["MANIFEST"]
changelog = os.environ["CHANGELOG"]
version = os.environ["VERSION"]
dry = os.environ["DRY_RUN"] == "1"

text = open(changelog, encoding="utf-8").read()
m = re.search(r"^## \[Unreleased\][^\n]*\n", text, re.M)
if not m:
    sys.stderr.write("error: no '## [Unreleased]' section in %s\n" % changelog)
    sys.exit(1)

start = m.end()
nxt = re.search(r"^## ", text[start:], re.M)
end = start + nxt.start() if nxt else len(text)
body = text[start:end].strip()
if not body:
    sys.stderr.write("error: [Unreleased] section is empty; nothing to release\n")
    sys.exit(1)

today = datetime.date.today().isoformat()
new_block = "## [Unreleased]\n\n## [%s] - %s\n\n%s\n\n" % (version, today, body)
new_text = text[:m.start()] + new_block + text[end:]

data = json.load(open(manifest, encoding="utf-8"))
old_version = data["version"]
data["version"] = version

print("plugin manifest : %s -> %s" % (old_version, version))
print("changelog       : [Unreleased] -> [%s] - %s" % (version, today))
print("released notes:")
for line in body.splitlines():
    print("  " + line)

if dry:
    print("\n(dry run — no files written)")
    sys.exit(0)

with open(changelog, "w", encoding="utf-8") as fh:
    fh.write(new_text)
with open(manifest, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PY

if [ "$dry_run" = "1" ]; then
  exit 0
fi

git add "$manifest" "$changelog"
git commit -q -m "Release $plugin v$version"
git tag -a "$tag" -m "$plugin v$version"

echo
echo "Released $plugin v$version (commit + tag $tag created locally)."
echo "Next:"
echo "  git push --follow-tags origin main"
echo "  gh release create $tag --title \"$plugin v$version\" --notes-from-tag   # optional"
