# revloop documentation

Guides for installing, configuring, and extending revloop. **Seven commands run two procedures.** Each
command in [`commands/`](../commands/) names one reviewer and offers only the flags that apply to it;
the procedure it runs is [`procedures/remote-loop.md`](../procedures/remote-loop.md), which drives a
reviewer on a pull request, or [`procedures/local-loop.md`](../procedures/local-loop.md), which drives
a review command on your machine and ends at a pushed branch with a pull request open on it, or at a
commit under `--no-publish`. A third,
[`procedures/severity-grading.md`](../procedures/severity-grading.md), is cited by both and owned by
neither. These pages surround them.

## Get started

- [Install](install.md) — put the plugin in place and confirm a reviewer answers
- [Permissions](permissions.md) — the rules to grant on Claude Code, the sandbox to open on Codex
- [Configuration](configuration.md) — `.revloop.json` reference, and what is detected without it

## Extend

- [Adding a reviewer](adding-a-reviewer.md) — measure a reviewer, bot or local command, and write its
  definition and its card

## Understand

- [Design notes](design-notes.md) — why the two procedures are shaped this way, and why the commands
  are one per reviewer
- [Known environment quirks](known-environment-quirks.md) — dated, non-normative observations

Contributing, the threat model, and the release history live at the repository root:
[CONTRIBUTING.md](../CONTRIBUTING.md), [SECURITY.md](../SECURITY.md),
[CHANGELOG.md](../CHANGELOG.md).
