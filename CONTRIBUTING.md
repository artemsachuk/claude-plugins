# Contributing

Thanks for your interest in improving these plugins.

## Repository layout

This is a multi-plugin Claude Code marketplace. Each plugin is self-contained
under `plugins/<name>/`:

```
.claude-plugin/marketplace.json   # lists every plugin
plugins/
  <name>/
    .claude-plugin/plugin.json    # the plugin manifest
    skills/ hooks/ tests/ ...      # whatever the plugin ships
    README.md                     # plugin-specific usage
```

## Adding a plugin

1. Create `plugins/<name>/` with a `.claude-plugin/plugin.json` manifest and a
   `README.md`.
2. Add an entry to the `plugins` array in `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<name>",
     "source": "./plugins/<name>",
     "description": "One line describing the plugin."
   }
   ```

3. If the plugin ships shell hooks, keep them defensive (fail quietly, never
   break the user's tool flow) and add tests under `plugins/<name>/tests/`.

## Running the tests locally

Each plugin's tests are plain bash scripts:

```bash
for t in plugins/*/tests/*.sh; do bash "$t"; done
```

Shell hooks are linted with [shellcheck](https://www.shellcheck.net/):

```bash
shellcheck plugins/*/hooks/*.sh
```

CI runs both of these on every push and pull request.

## Trying a change locally

Point Claude Code at your working copy and install from it:

```
/plugin marketplace add /absolute/path/to/claude-plugins
/plugin install <name>@as-claude-plugins
/reload-plugins
```

## Releasing

Plugins version and release independently. See [RELEASING.md](RELEASING.md) for
the changelog convention and the `scripts/release.sh` workflow.
