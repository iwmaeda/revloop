# Install

Put revloop in place on Claude Code or Codex, then confirm a reviewer bot answers. Permission rules
are not here — they are in [`permissions.md`](permissions.md).

## Quickstart

### Claude Code

```console
/plugin marketplace add iwmaeda/revloop
/plugin install revloop@revloop
```

The command is then `/revloop:review-loop`. Plugin-provided commands are always namespaced as
`/<plugin>:<command>`, so there is no bare `/revloop`.

It is deliberately not model-invocable (`disable-model-invocation: true`), and the Claude Code
plugin manifest ships no `skills` key. This loop pushes, comments on pull requests, and can merge;
it should only ever start because a person asked for it.

### Codex

Codex plugin support is in preview. The reliable path today is to place the skill directly:

```console
git clone https://github.com/iwmaeda/revloop.git ~/.revloop
mkdir -p .agents/skills
cp -r ~/.revloop/.agents/skills/revloop .agents/skills/
export REVLOOP_PROCEDURE=~/.revloop/commands/review-loop.md
```

`.agents/skills/revloop/SKILL.md` is a router, not a copy of the procedure: it resolves
`commands/review-loop.md` and reads it. `REVLOOP_PROCEDURE` is what makes that work once the skill has
been copied away from the repository — without it the router searches relative to itself, then upward,
and aborts if it finds nothing rather than improvising.

Codex grants shell and network access through an approval policy and a sandbox rather than an
allowlist; see
[Codex: approval policy and sandbox](permissions.md#codex-approval-policy-and-sandbox).
`.codex-plugin/plugin.json` is already in place for when `codex plugin install` ships.

## Prerequisites

revloop assumes a reviewer that already answers. It posts a trigger and waits for a verdict only the
reviewer can produce; it installs nothing. A `@codex review` comment goes to
`chatgpt-codex-connector[bot]`, which reads the pushed diff and reviews it independently — it is not
the Codex or Claude Code session you are running, and that session cannot answer on its behalf.
Installing the integration happens on the reviewer's own GitHub App page, outside this project's
scope.

To confirm it works, comment `@codex review` by hand on any open pull request and check that the bot
replies. For how long the loop then waits, see [How it works](../README.md#how-it-works); the budgets
that bound it are in [`commands/review-loop.md`](../commands/review-loop.md).

## Requirements

| Tool  | Floor                | Note                                                                                          |
| ----- | -------------------- | --------------------------------------------------------------------------------------------- |
| `gh`  | **2.4.0** (verified) | Authenticated. Only stable REST and GraphQL surfaces are used                                 |
| `git` | **2.22** (derived)   | `git branch --show-current`, 2019-06. Verified against 2.34.1; the floor itself is by feature |
| `jq`  | **not required**     | `gh` embeds a jq implementation; the procedure never pipes to `jq`                            |

The two floors are graded differently on purpose. `gh` 2.4.0 is where the procedure was actually
driven — the version a machine had, not one chosen from a changelog. `git` 2.22 is the release that
introduced the one command every fence depends on, so it is derived, and labelled as such. The
optional `git switch` alternative in step 2 needs 2.23. The reviewer bot is a requirement too, but not
a local one — see [Prerequisites](#prerequisites).

## Verify the install

```console
/revloop:review-loop
```

On a clean tree with no changes it should print the resolved-configuration table and stop. If it
prints a permission prompt for every step, work through [`permissions.md`](permissions.md).

## Related docs

- [Permissions](permissions.md) — what to grant once revloop is in place
- [Configuration](configuration.md) — `.revloop.json`, and what is detected without it
- [Known environment quirks](known-environment-quirks.md) — if `jq` or a version manager misbehaves
