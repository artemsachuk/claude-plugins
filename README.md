# claude-plugins

[![CI](https://github.com/artemsachuk/claude-plugins/actions/workflows/ci.yml/badge.svg)](https://github.com/artemsachuk/claude-plugins/actions/workflows/ci.yml)

A small open marketplace of [Claude Code](https://docs.claude.com/en/docs/claude-code/overview)
plugins by Artem Sachuk.

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
