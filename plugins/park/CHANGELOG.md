# Changelog

All notable changes to the `park` plugin are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-06-30

### Added
- Scope-guard (`park` skill Mode E): detects when a change is drifting from the
  branch's goal and offers to park it — capturing the diff and reverting the
  files, with honest handling of irreversible side effects (migrations,
  installed dependencies).
- Nudge hook now also fires on a "new-area" edit (a file in a directory the
  branch has not touched), not only on spec/plan writes. Per-branch
  `accepted_areas` in `.git/park-scope/` suppress repeat nudges once a tangent
  is accepted as in-scope.

## [0.1.0] - 2026-06-30

### Added
- Initial release of `park`: a companion to superpowers for setting work aside
  and resuming it later.
- `park` skill with four modes — park an idea/bug/spec, list parked items,
  resume one, and complete it.
- PostToolUse nudge hook that suggests parking when a spec or plan is written
  mid-feature on a non-`main` branch with real work in progress.
