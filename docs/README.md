# revloop documentation

Guides for installing, configuring, and extending revloop. The procedures the loops actually execute
are [`commands/review-loop.md`](../commands/review-loop.md), which drives a reviewer on a pull
request, and [`commands/review-loop-local.md`](../commands/review-loop-local.md), which drives a
review command on your machine and ends at a commit. These pages surround them.

## Get started

- [Install](install.md) — put the plugin in place and confirm a reviewer answers
- [Permissions](permissions.md) — the rules to grant on Claude Code, the sandbox to open on Codex
- [Configuration](configuration.md) — `.revloop.json` reference, and what is detected without it

## Extend

- [Adding a reviewer](adding-a-reviewer.md) — measure a reviewer, bot or local command, and write
  its card

## Understand

- [Design notes](design-notes.md) — why the two loops are shaped this way
- [Known environment quirks](known-environment-quirks.md) — dated, non-normative observations

Contributing, the threat model, and the release history live at the repository root:
[CONTRIBUTING.md](../CONTRIBUTING.md), [SECURITY.md](../SECURITY.md),
[CHANGELOG.md](../CHANGELOG.md).
