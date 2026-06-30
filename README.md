<div align="center">

<h1>claude-plugins</h1>

<p>A curated collection of Claude Code plugins by Artem Sachuk.<br>
Browse, install, and contribute composable tools for your Claude workflow.</p>

<p>
  <a href="https://github.com/artemsachuk/claude-plugins/releases/latest"><img src="https://img.shields.io/github/v/release/artemsachuk/claude-plugins?label=release" alt="Release" /></a> &nbsp;
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-555.svg" alt="License" /></a> &nbsp;
  <img src="https://img.shields.io/badge/Claude%20Code-plugin-f5b800.svg" alt="Claude Code plugin" /> &nbsp;
  <a href="https://github.com/artemsachuk/claude-plugins/actions/workflows/ci.yml"><img src="https://github.com/artemsachuk/claude-plugins/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
</p>

</div>

## Add the marketplace

Inside Claude Code:

```
/plugin marketplace add artemsachuk/claude-plugins
```

Then install any plugin from it:

```
/plugin install <name>@as-claude-plugins
/reload-plugins
```

## Plugins

| Plugin | Description |
| ------ | ----------- |
| [park](plugins/park/) | Park ideas, bugs, and specs that surface mid-feature, then resume them later as separate work. Companion to [superpowers](https://github.com/obra/superpowers). |

### Install park

```
/plugin marketplace add artemsachuk/claude-plugins
/plugin install park@as-claude-plugins
/reload-plugins
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add a plugin and run the tests,
and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for participation guidelines.

## License

[MIT](LICENSE) © Artem Sachuk
