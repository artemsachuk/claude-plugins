# Releasing

Each plugin in this marketplace versions and releases independently. Releases are
cut by hand with a helper script — there is no CI publishing.

## Versioning

- Each plugin follows [Semantic Versioning](https://semver.org).
- The source of truth for a plugin's version is its
  `plugins/<plugin>/.claude-plugin/plugin.json`.
- Tags are per-plugin: `<plugin>-v<version>` (e.g. `park-v0.2.0`).

## During development

As you change a plugin, record user-facing changes under the `## [Unreleased]`
section of `plugins/<plugin>/CHANGELOG.md` (Added / Changed / Fixed / Removed).

## Cutting a release

From a clean `main`:

```bash
# preview what would change (writes nothing)
scripts/release.sh --dry-run park 0.2.0

# do it
scripts/release.sh park 0.2.0
```

The script will:

1. Validate you're on `main` with a clean tree, the version is valid semver and
   greater than the current one, and `[Unreleased]` has content.
2. Bump the version in the plugin manifest.
3. Roll `[Unreleased]` into a dated `## [0.2.0] - YYYY-MM-DD` section.
4. Commit `Release park v0.2.0` and create the annotated tag `park-v0.2.0`.

It does **not** push. Finish with:

```bash
git push --follow-tags origin main
```

Optionally publish a GitHub Release from the tag:

```bash
gh release create park-v0.2.0 --title "park v0.2.0" --notes-from-tag
```
